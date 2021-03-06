-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
--                                                                         --
--  This file is part of the DSP-Crowd project                             --
--  https://www.dsp-crowd.com                                              --
--                                                                         --
--  Author(s):                                                             --
--      - Johannes Natter, office@dsp-crowd.com                            --
--                                                                         --
-----------------------------------------------------------------------------
--                                                                         --
--  Copyright (C) 2017 Authors and www.dsp-crowd.com                       --
--                                                                         --
--  This program is free software: you can redistribute it and/or modify   --
--  it under the terms of the GNU General Public License as published by   --
--  the Free Software Foundation, either version 3 of the License, or      --
--  (at your option) any later version.                                    --
--                                                                         --
--  This program is distributed in the hope that it will be useful,        --
--  but WITHOUT ANY WARRANTY; without even the implied warranty of         --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the           --
--  GNU General Public License for more details.                           --
--                                                                         --
--  You should have received a copy of the GNU General Public License      --
--  along with this program. If not, see <http://www.gnu.org/licenses/>.   --
--                                                                         --
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gpio_ext is
	generic
	(
		my_id			: natural := 0
	);
	port
	(
		clock			: in   std_ulogic;
		n_reset_async		: in   std_ulogic;

		spi_cs			: in   std_ulogic;

		data			: in   std_ulogic_vector(7 downto 0);
		data_is_id		: in   std_ulogic;
		data_valid		: in   std_ulogic;

		input_state		: out  std_ulogic;
		input_state_valid	: out  std_ulogic;
		cmd_done		: out  std_ulogic;

		gpio_in			: in   std_ulogic;
		gpio_out		: out  std_ulogic;
		gpio_en			: out  std_ulogic
	);
begin
	assert (my_id >= 0)
		report "gpio_ext: id must be at least 1"
		severity error;
end gpio_ext;

architecture rtl of gpio_ext is

	type STATEMACHINE_MAIN_STEP_TYPE is
	(
		SM_WAIT_SELECTED, SM_GET_CMD, SM_CHECK_CMD, SM_GET_INPUT, SM_GET_DUMMY, SM_SET_OUTPUT, SM_GET_COUNTER_MAX, SM_GET_COUNTER_MID
	);

	type GPIO_TYPE is
	(
		GPIO_INPUT, GPIO_OUTPUT, GPIO_PWM
	);

	subtype BYTE_IDX_TYPE is integer range 0 to 3;

	type REG_TYPE is record
		sm_step			: STATEMACHINE_MAIN_STEP_TYPE;
		data			: std_ulogic_vector(7 downto 0);
		counter			: natural;
		counter_max		: natural;
		counter_mid		: natural;
		byte_idx		: BYTE_IDX_TYPE;
		tmp			: std_ulogic_vector(23 downto 0);
		gpio_type		: GPIO_TYPE;
		gpio			: std_ulogic;
	end record;

	constant RSET_INIT_VAL : REG_TYPE :=
	(
		sm_step			=> SM_WAIT_SELECTED,
		data			=> (others => '0'),
		counter			=> 0,
		counter_max		=> 0,
		counter_mid		=> 0,
		byte_idx		=> 0,
		tmp			=> (others => '0'),
		gpio_type		=> GPIO_INPUT,
		gpio			=> '0'
	);

	signal R, NxR			: REG_TYPE;

begin

	proc_comb: process(R, spi_cs, data, data_is_id, data_valid, gpio_in)
	begin
		NxR <= R;

		input_state <= '0';
		input_state_valid <= '0';
		cmd_done <= '0';
		gpio_out <= R.gpio;

		if(R.gpio_type = GPIO_OUTPUT or R.gpio_type = GPIO_PWM)then
			gpio_en <= '1';
		else
			gpio_en <= '0';
		end if;

		if(R.gpio_type = GPIO_PWM)then
			if(R.counter < R.counter_max - 1)then
				NxR.counter <= R.counter + 1;
			else
				NxR.counter <= 0;
			end if;

			if(R.counter < R.counter_mid)then
				NxR.gpio <= '1';
			else
				NxR.gpio <= '0';
			end if;
		end if;

		case R.sm_step is
			when SM_WAIT_SELECTED =>
				if(data_is_id = '1' and to_integer(unsigned(data)) = my_id)then
					NxR.sm_step <= SM_GET_CMD;
				end if;

			when SM_GET_CMD =>
				if(data_valid = '1')then
					NxR.data <= data;
					NxR.sm_step <= SM_CHECK_CMD;
				end if;

			when SM_CHECK_CMD =>
				if(R.data(1 downto 0) = "00")then	-- read
					NxR.gpio_type <= GPIO_INPUT;

					NxR.sm_step <= SM_GET_INPUT;
				elsif(R.data(1 downto 0) = "01")then	-- write
					NxR.gpio_type <= GPIO_OUTPUT;

					NxR.sm_step <= SM_SET_OUTPUT;
				else					-- pwm
					NxR.byte_idx <= 3;

					NxR.sm_step <= SM_GET_COUNTER_MAX;
				end if;

			when SM_GET_INPUT =>
				input_state <= gpio_in;
				input_state_valid <= '1';

				NxR.sm_step <= SM_GET_DUMMY;

			when SM_GET_DUMMY =>
				if(data_valid = '1')then
					cmd_done <= '1';

					NxR.sm_step <= SM_WAIT_SELECTED;
				end if;

			when SM_SET_OUTPUT =>
				if(data_valid = '1')then
					cmd_done <= '1';
					NxR.gpio <= data(0);

					NxR.sm_step <= SM_WAIT_SELECTED;
				end if;

			when SM_GET_COUNTER_MAX =>
				if(data_valid = '1')then
					if(R.byte_idx = 0)then
						NxR.counter_max <= to_integer(unsigned(R.tmp & data));
						NxR.byte_idx <= 3;

						NxR.sm_step <= SM_GET_COUNTER_MID;
					else
						NxR.tmp(8 * R.byte_idx - 1 downto 8 * (R.byte_idx - 1)) <= data;
						NxR.byte_idx <= R.byte_idx - 1;
					end if;
				end if;

			when SM_GET_COUNTER_MID =>
				if(data_valid = '1')then
					if(R.byte_idx = 0)then
						NxR.counter_mid <= to_integer(unsigned(R.tmp & data));
						NxR.gpio_type <= GPIO_PWM;
						cmd_done <= '1';

						NxR.sm_step <= SM_WAIT_SELECTED;
					else
						NxR.tmp(8 * R.byte_idx - 1 downto 8 * (R.byte_idx - 1)) <= data;
						NxR.byte_idx <= R.byte_idx - 1;
					end if;
				end if;

			when others =>
				NxR.sm_step <= SM_WAIT_SELECTED;
		end case;

		if(spi_cs = '1')then
			NxR.sm_step <= SM_WAIT_SELECTED;
		end if;

	end process;

	proc_reg: process(n_reset_async, clock)
	begin
		if(n_reset_async = '0')then
			R <= RSET_INIT_VAL;
		elsif(clock'event and clock = '1')then
			R <= NxR;
		end if;
	end process;

end architecture rtl;
