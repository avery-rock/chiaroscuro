%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% "Chiaroscuro" still life drawing robot, EECS 206A Final Project, Group 39: Avery Rock
% email: avery_rock@berkeley.edu
% SID: 3034290042
% Dec. 12, 2019.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all; close all; clc;

% s = startup_serial(); fopen(s);
% 
% % fwrite(s,

%% SYSTEM GEOMETRY

r = [135, 147, 60]; % link lengths, mm
pen_z = 2*25.4; % length of pen below the top of the end effector, mm
base_z = 135; % height of origin from table.
pen_tol = 0; % tolerance for pushing pen deeper onto paper.
paper_dims = [8*25.4, 12.5*25.4, -3.5*25.4, 3.5*25.4, pen_z - base_z - pen_tol]; % minx, maxx, miny, maxy, z
travel_z = paper_dims(5) + 20; % height for transit between line segments.

%% OPEN SERIAL COMMUNICATION WITH DOBOT

s = startup_serial(); fopen(s);

%% START CAMERA, RECORD IMAGE

toPoint(0, 100, 100, s); 



%% 


try
    cam = start_cam(); % try to start the camera and record a snapshot
    I = snapshot(cam);
catch
    I = imread('flipped_danny.jpg'); % draw danny devito if an error occurs.
end
[x, y, xscale, yscale] = drawme2(I);  % return paths

scale = min(paper_dims(4) - paper_dims(3), paper_dims(2) - paper_dims(1)); % find the more constricting dimension
minx = paper_dims(1);
miny = paper_dims(3);

%% PREVIEW DRAWING
figure(); hold on % display preview of drawing.
for i = 1:numel(x)
    plot(x{i}*scale + minx, y{i}*scale + miny, 'k-', 'LineWidth', .01)
end
hold off
axis equal

home_payload = {'1F','00','00'}; % homing command
home_cmd = make_cmd(home_payload);
fwrite(s, home_cmd)
pause(20)

%%
toPoint(250, 0, 0, s);

%% PTP DRAWING
for i = 1:numel(x)
    xx = x{i}*scale + minx; yy = y{i}*scale + miny;
    pause(1)
    
    toPoint(xx(1), yy(1), travel_z, s);
    for j = 1:numel(x{i})
        toPoint(xx(j), yy(j), paper_dims(5), s);
        pause(.01)
    end
    
    toPoint(xx(j), yy(j), travel_z, s); % pick back up
    pause(.2)
end

toPoint(r(2) + r(3), 0, r(1), s); % perfectly upright


%% CP DRAWING

% set CP velocity and acceleration



%% SHUT DOWN
toPoint(100, 0, 0, s)
fclose(s);

%%

function cam = start_cam()
cam = webcam(2);
preview(cam); pause(1)
end

function s = startup_serial()

if ~isempty(instrfind) % clear away old gunk
    fclose(instrfind);
    delete(instrfind);
end

serial_devices = seriallist; % find all serial devices
% s = serial(serial_devices(1)); % windows syntax
% sprintf(serial_devices);
s = serial(serial_devices(3), 'BaudRate', 115200); % connect to the last one (verify this in general)
s.Terminator = '';
end

function toPoint(x, y, z, s)
payload = PTP_payload(x, y, z);
PTP_cmd = make_cmd(payload);
%     disp(PTP_cmd')
fwrite(s, PTP_cmd);
end

function payload = SetCPParams_payload(Acc, Vel, period)

id = {'90'};
rwq = {'11'};
params = hexcoords([Acc, Vel, period]);
mode = {'01'}; % real time: 1

payload = [id, rwq, params, mode];
end

function CP_queue(x, y, z, s)
payload = CP_payload(x, y, z);
cmd = make_cmd(payload);
fwrite(s, cmd);
end

function payload = CP_payload(x, y, z)
id = {'91'};
rwq = {'11'};
mode = {'01'}; % 1: absolute. 0: relative
vel = 100; % velocity units???
params = hexcoords(x, y, z, vel);
payload = [id, rwq, mode, params];
end

function checkQueue(s)
id = {hex2dec(246)};
rwq = {'00'};
payload = [id, rwq];
cmd = make_cmd(payload);
returned = fread(s, 3 + 2 + 8); % read the returned command packet
end

function STOP(s)
id = {dec2hex(242)};
rwq = {'10'};
payload = [id, rwq];
cmd = make_cmd(payload);
fwrite(s, cmd);
fprintf("Command queue forcibly stopped");
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

% it's literally just easier to reconstruct it manually??
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

function out = getPose_payload()
id = {'10'};
rwq = {'00'};
out = [id, rwq];
end

% function float7542dec(b)
% s = b(1); e = b(2:9) - 127; m = b(10:end);
% 
% mantissa = 1;
% 
% for
%     
%     out = ((-1)^s)*(2^e) *
%     
% end
% end

    function out = getPose(s)
        payload = getPose_payload();
        getPose_cmd = make_cmd(payload);
        fwrite(s, getPose_cmd);
        pose = fread(s, 3 + 34);
        out = pose; % need to invert the float thing to get actual numbers out of this: doable
    end
