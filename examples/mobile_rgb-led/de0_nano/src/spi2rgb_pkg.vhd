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
--  Copyright (C) 2015 Authors and www.dsp-crowd.com                       --
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

package spi2rgb_pkg is

	---------------------------------------------------------------------
	-- Constants / Types
	---------------------------------------------------------------------
	constant SPI2RGB_NUM_DATA_BYTES : natural := 3;
	type SPI2RGB_DATA_TYPE is array (SPI2RGB_NUM_DATA_BYTES - 1 downto 0) of std_ulogic_vector(7 downto 0);

end spi2rgb_pkg;
