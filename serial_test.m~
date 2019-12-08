
clear all; close all; clc;

% aa aa 03 1f 00 00 e1 % move around




% procedure: 

% pair to arm
% pair to camera, turn it on. 

% move camera to position to look at scene, snap a picture, return paths. 
% move camera to position to look at paper, check if paper is there
% (ideally do the movement while the planning is going on)
% if paper is not detected, throw an error and stop. 
% if paper is detected, begin drawing sequence. 

% drawing sequence: for each path returned, put the pen down, begin a
% continuous path, pick up at end. Repeat until all paths are completed. No
% idea how to deal with errors. 

s = startup_serial(); 

fopen(s);

gotoConfig = hex2dec({'AA','AA','03', '1F','00','00','E1'}); % homing command
fwrite(s,gotoConfig);


% fread(s, 8)
% thing = read(s, 8, 'char')

disp(s)
fclose(s); 


function s = startup_serial()

if ~isempty(instrfind) % cler away old gunk
    fclose(instrfind);
    delete(instrfind);
end

serial_devices = seriallist; % find all serial devices
sprintf(serial_devices(3)); 
s = serial(serial_devices(3), 'BaudRate', 115200); % connect to the last one (verify this in general)
s.Terminator = '';
end

function SetCPParams(x, y, z)
header = {'AA', 'AA'}; 
len = 15; 
id = 90; 
rw = 1; 

isQ = 1; 

end

function setPTPCmd(x, y, z, r)

header = {'AA', 'AA'}; 
len = {'13'}; 
id = {'54'}; 
rw = {'03'}; 

isQ = 1; 



end

function out = getPose()
header = {'AA', 'AA'};
len = {'02'}; 
id = {'0A'}; 
rw = {'00'}; 
payload = {}; 
CS = {'F6'};

out = hex2dec([header, len, id, rw, payload, CS]); 

end
