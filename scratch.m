%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% "Scratch" still life drawing robot, EECS 206A Final Project

% Project submitted Dec. 12, 2019.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function scratch

cleanupObj = onCleanup(@(s)cleanMeUp); % define shutdown sequence

%% SYSTEM GEOMETRY

r = [135, 147, 60]; % link lengths, mm
pen_z = 2*25.4; % length of pen below the top of the end effector, mm
base_z = 135; % height of origin from table.
pen_tol = 4; % tolerance for pushing pen deeper onto paper.
ws = [8*25.4, 11.5*25.4, -4.5*25.4, 4.5*25.4, pen_z - base_z - pen_tol]; % minx, maxx, miny, maxy, z
travel_z = ws(5) + 15; % height for transit between line segments.

%% OPEN COMMUNICATION
try
    s = startup_serial(); fopen(s); % open serial communication with dobot
    home_payload = {'1F','00','00'}; % define homing command payload
    home_cmd = make_cmd(home_payload); % convert to homing command
    fwrite(s, home_cmd) % write command to dobot
    pause(20); % wait for homing to complete.
    
    toPoint(0, 300, 110, s); % go to good point for seeing paper
    pause(5)
    
    try
        cam = start_cam(); % try to start the camera and record a snapshot
    catch
        fprintf("cam already defined \n\n")
    end
    I = snapshot(cam); % record single image from camera
catch
    I = imread("dannydevito.jpg"); % if camera throws an error, draw danny devito.
end

%% PLAN DRAWING
[x, y, xscale, yscale] = myDrawing(I);  % return line drawing paths and scale
scale = min((ws(4) - ws(3))/yscale, (ws(2) - ws(1))/xscale); % find the more constricting dimension
minx = ws(1); maxx = ws(2); miny = ws(3); maxy = ws(4);

%% PREVIEW DRAWING
figure(); hold on % display preview of drawing.
for i = 1:numel(x)
    plot(y{i}*scale + miny, x{i}*scale + maxx,'k-', 'LineWidth', .1)
end
xlabel("Dobot Y Coordinate"); ylabel("Dobot X Coordinate");
hold off; axis equal

%% CREATE DRAWING
try
    toPoint(180, 0, -20, s); % move to central location to check for paper
    pause(5)
    
    if checkForPaper(cam)
        for i = 1:numel(x) % PTP DRAWING
            xx = x{i}*scale + maxx; yy = -y{i}*scale + maxy;
            pause(1)
            toPoint(xx(1), yy(1), travel_z, s);
            for j = 1:numel(xx)
                toPoint(xx(j), yy(j), ws(5), s);
                pause(.1)
            end
            toPoint(xx(j), yy(j), travel_z, s); % pick back up
            pause(1)
        end
        toPoint(r(2) + r(3), 0, r(1), s); % perfectly upright
        
    else
        fprintf("No paper detected. Shutting down safely...\n\n")
    end
catch
    fprintf("Unexpected error occured. Shutting down safely... 'n'n")
end

    function cam = start_cam()
        cam = webcam(2);
        preview(cam); pause(1)
    end

    function out = checkForPaper(cam)
        out = 0;
        I = snapshot(cam); % take a picture once
        I = rgb2gray(I); % convert to black and white
        [h, w] = size(I);
        light = I > mean(I(:)); % array of lighter-than-average pixels
        midblock = light(ceil(h/3):end, floor(w/5):ceil(4*w/5)); % check if light area matches well with expected arrangement
        if nnz(midblock)/numel(midblock) > .9 % if more than 90% of the pixels in the region where the paper should be are light, go ahead.
            out = 1;
        end
    end

    function s = startup_serial()
        
        if ~isempty(instrfind) % clear away old gunk
            fclose(instrfind);
            delete(instrfind);
        end
        
        serial_devices = seriallist; % find all serial devices
        s = serial(serial_devices(4), 'BaudRate', 115200); % connect to the last one (verify this in general)
        s.Terminator = '';
    end

    function toPoint(x, y, z, s)
        payload = PTP_payload(x, y, z);
        PTP_cmd = make_cmd(payload);
        %     disp(PTP_cmd')
        fwrite(s, PTP_cmd);
    end

    function payload = CP_payload(x, y, z)
        id = {'5B'};
        rwq = {'03'};
        mode = {'01'}; % 1: absolute. 0: relative
        vel = 100; % velocity units???
        params = hexcoord([x, y, z, 1]);
        payload = [id, rwq, mode, params];
    end

    function out = checkQueue(s)
        id = {hex2dec(246)};
        rwq = {'00'};
        payload = [id, rwq];
        cmd = make_cmd(payload);
        fwrite(s, cmd);
        out = fread(s, 3 + 2 + 8); % read the returned command packet
    end

    function payload = PTP_payload(x, y, z)
        id = {'54'};
        rwq = {'03'};
        mode = {'01'};
        params = hexcoord([x, y, z, 0]);
        payload = [id, rwq, mode, params];
    end

    function out = checksum(payload)
        % compute checksum by finding bitwise complement of bytewise sum of command
        % payload.
        
        tot = 0;
        for i = 1:numel(payload)
            tot = tot + hex2dec(payload{i});
        end
        out = dec2hex(2^8 - mod(tot, 2^8));
    end

    function out = make_cmd(payload)
        % convert payload into valid serial command for dobot magician
        header = {'AA', 'AA'};
        len = {dec2hex(numel(payload), 2)};
        cs = {checksum(payload)};
        out = uint8(hex2dec([header, len, payload, cs]));
    end

    function out = hexcoord(coords)
        % converts an array of floats into hex floats
        % disp(coords)
        out = cell(0);
        for i = 1:numel(coords)
            out = [out, hexfloat(coords(i))];
        end
    end

    function s = hexfloat(d)
        % this function converts a number d into a 4-byte float in IEEE-754 little
        % endian notation for use with dobot serial communication.
        % https://www.h-schmidt.net/FloatConverter/IEEE754.html
        
        b = false(1, 32); % empty binary array
        if d ~= 0
            b(1) = d < 0; % sign bit
            exp = 127 + floor(log2(abs(d))); % exponent
            b(2:9) = flip(bitget(uint8(exp), 1:8)); % exponent
            m = abs(d) * 2^(127-exp);  % mantissa,
            
            m_array = false(1, 23);
            m = m - 1; % leading 1 dropped.
            for i = 1:numel(m_array)
                if m >= 2^(-i)
                    m_array(i) = true;
                    m = m - 2^(-i);
                end
            end
            b(10:end) = m_array;
        end
        
        hex_str = bin2hex(b);
        s = cell(0);
        for i = 1:numel(hex_str)/2
            s = [{hex_str(1 + 2*(i - 1):2*i )}, s];
        end
    end

    function out = bin2hex(bin_array)
        % take in an array of n x 4-bit binary data and converts it to n x 1 hex.
        
        b_str = num2str(bin_array); % convert to binary strings
        b_str(isspace(b_str)) = ''; % remove spaces
        vals = bin2dec(b_str);
        out = dec2hex(vals, 8);
    end

    function cleanMeUp(s)
        toPoint(r(2) + r(3), 0, r(1), s); % perfectly upright
        fprintf('Shutting down...\n\n');
        pause(5)
        fclose(s);
        clear all; close all; clc
    end
end
