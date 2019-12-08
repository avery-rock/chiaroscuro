clear all; close all; clc


cam = webcam(2); 
preview(cam)
pause(5)
I = snapshot(cam); 

clear cam

figure()
imshow(I)

[x, y] = drawme2(I, 1, 1) % return paths