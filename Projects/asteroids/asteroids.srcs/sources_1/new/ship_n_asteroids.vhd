LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.MATH_REAL.ALL;

ENTITY ship_n_asteroids IS 
    PORT (
        v_sync : IN STD_LOGIC;
        pixel_row : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        pixel_col : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        ship_x : IN STD_LOGIC_VECTOR(10 DOWNTO 0); -- Ship's current x position
        start : IN STD_LOGIC; -- Start / Reset button
        red : OUT STD_LOGIC;
        green : OUT STD_LOGIC;
        blue : OUT STD_LOGIC;
        SW : IN STD_LOGIC_VECTOR (4 DOWNTO 0); -- Asteroid speed
        hits : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) -- Count asteroids hit in current life
    );
END ship_n_asteroids;

ARCHITECTURE Behavioral OF ship_n_asteroids IS
    -- Initialize game
    SIGNAL game_on : STD_LOGIC := '1'; -- Indicates whether player is still alive
    SIGNAL ship_on : STD_LOGIC; -- Indicates whether ship is at/over current pixel position
    SIGNAL ast_on : STD_LOGIC; -- Indicates whether asteroid is in play
    SIGNAL hitcount_on : STD_LOGIC := '1'; -- Indicates whether hitcount should continue
    SIGNAL hitcount : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL stop_dbl_hit : STD_LOGIC; -- stops counter from registering 2 hits at once
    SIGNAL stop_dbl_size : STD_LOGIC; -- stops asteroid size icrease from happening multiple times

    -- Initialize 
    SIGNAL ast_size : INTEGER := 20; -- asteroid size in pixels
    SIGNAL ast_x : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(400,11);
    SIGNAL ast_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(0,11);
    SIGNAL ast_speed : STD_LOGIC_VECTOR(10 DOWNTO 0);
    SIGNAL ast_x_motion : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(0,11);
    SIGNAL ast_y_motion : STD_LOGIC_VECTOR(10 DOWNTO 0) := ast_speed;

    -- Initialize ship
    CONSTANT ship_size : INTEGER := 40; -- Ship size in pixels (height and width)
    CONSTANT ship_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(500, 11); -- Ship y position

BEGIN
    red <= ast_on and NOT ship_on;
    blue <= ship_on;
    green <= ship_on and NOT ast_on;
    
    game_on <= '1';

    astDraw : PROCESS (ast_x, ast_y, pixel_row, pixel_col) IS
        VARIABLE vx, vy : STD_LOGIC_VECTOR (10 DOWNTO 0); -- 9 downto 0
    BEGIN
        IF pixel_col <= ast_x THEN -- vx = |ast_x - pixel_col|
            vx := ast_x - pixel_col;
        ELSE
            vx := pixel_col - ast_x;
        END IF;
        IF pixel_row <= ast_y THEN -- vy = |ast_y - pixel_row|
            vy := ast_y - pixel_row;
        ELSE
            vy := pixel_row - ast_y;
        END IF;
        IF ((vx * vx) + (vy * vy)) < (ast_size * ast_size) THEN -- test if radial distance < ast_size
            ast_on <= game_on;
        ELSE
            ast_on <= '0';
        END IF; 
    END PROCESS;

    shipDraw : PROCESS (ship_x, pixel_row, pixel_col) IS
        VARIABLE vx, vy : STD_LOGIC_VECTOR (10 DOWNTO 0); -- 9 downto 0
    BEGIN
        IF ((pixel_col >= ship_x - ship_size) OR (ship_x <= ship_size)) AND
         pixel_col <= ship_x + ship_size AND
             pixel_row >= ship_y - ship_size AND
             pixel_row <= ship_y + ship_size THEN
                ship_on <= '1';
        ELSE
            ship_on <= '0';
        END IF;
    END PROCESS;

    moveAsteroids : PROCESS 
        VARIABLE temp : STD_LOGIC_VECTOR (11 DOWNTO 0);
        VARIABLE count : INTEGER := 0; -- For pseudorandomness
    BEGIN
        WAIT UNTIL rising_edge(v_sync);
        count := ((count * 17) + 19) mod 800; -- Pseudorandom asteroid placements
        IF start = '1' THEN -- Wait for start game signal
            game_on <= '1';
            ast_size <= 20;
            ast_speed <= (10 DOWNTO SW'length => '0') & SW;
            ast_y <= CONV_STD_LOGIC_VECTOR(0,11);
            hitcount <= CONV_STD_LOGIC_VECTOR(0,16);
            stop_dbl_hit <= '0';
        ELSIF ast_y + ast_size/2 <= 150 THEN -- Reset flags
            stop_dbl_size <= '0';
            hitcount_on <= '1';
        ELSIF game_on <= '1' AND ast_y - ast_size >= 650 AND stop_dbl_size <= '1' AND hitcount_on = '1' THEN -- if asteroid passes player
            stop_dbl_hit <= '0';
            ast_y <= CONV_STD_LOGIC_VECTOR(-200 - ast_size, 11);
            ast_x <= CONV_STD_LOGIC_VECTOR(count, 11);
            IF stop_dbl_size = '0' THEN
                ast_size <= ast_size + 1;
                stop_dbl_size <= '1';
            END IF;
            IF hitcount_on = '1' THEN
                hitcount <= hitcount + 1;
                hits <= hitcount;
                hitcount_on <= '0';
            END IF;
        END IF;
        
        IF  game_on <= '1' AND
            (ast_x + ast_size/2) >= (ship_x - ship_size) AND
            (ast_x - ast_size/2) <= (ship_x + ship_size) AND
            (ast_y + ast_size/2) >= (ship_y - ship_size) AND
            (ast_y - ast_size/2) <= (ship_y + ship_size) AND
            stop_dbl_hit = '0' THEN
                stop_dbl_hit <= '1';
                ast_y <= CONV_STD_LOGIC_VECTOR(1000, 11);
                ast_speed <= CONV_STD_LOGIC_VECTOR(0, 11);
                hitcount <= CONV_STD_LOGIC_VECTOR(0,16);
                hits <= hitcount;
        END IF;

        -- compute next asteroid vertical position
        -- variable temp adds one more bit to calculation to fix unsigned underflow problems
        -- when ast_y is close to zero and ast_y_motion is negative
        temp := ('0' & ast_y) + (ast_y_motion(10) & ast_y_motion);
        IF game_on = '0' THEN
            ast_y <= CONV_STD_LOGIC_VECTOR(0, 11);
        ELSIF temp(11) = '1' THEN
            ast_y <= (OTHERS => '0');
        ELSE ast_y <= temp(10 DOWNTO 0); -- 9 downto 0
        END IF;

    END PROCESS;
END Behavioral;