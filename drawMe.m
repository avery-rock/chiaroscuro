close all; clear all; clc;

% PARAMETERS
ne = 1000; % number of edge points
nd = 500; % number of dark points
nt = 1000; % number of total points to plot
drawings = 20;
dec = 150;
markov_decay = .5;
filter_size = 6;
e2e = 10; % edge to edge relative prob
d2d = 1; % dark to dark relative prob
gridx = 1;
gridy = 1;
canvas = .9;
noise = 15;
sa = [.1, .25]; % signature area

% LOAD IMAGE
I = imread('input_images/dannydevito.jpg');
I = imresize(I, 500/size(I, 1));
I = double(rgb2gray(I));

% EDGE DETECTION

BWs = single(edge(I, 'canny', [], 5));
h = fspecial('gaussian', 5, 2);
% BWs = imgradient(I);
BWs = imfilter(BWs, h);
BWs = BWs / max(BWs(:));

% fudgeFactor = 0.9;

[xe, ye] = ind2sub(size(BWs), vecProb(BWs(:).^2, ne)); % edge points
% [xe, ye] = ind2sub(size(BWs), find(BWs(:)));
i = randsample(1:numel(xe), ne);
xe = xe(i); ye = ye(i);

I_dark = single(max(I(:)) - I(:))/255;
[xd, yd] = ind2sub(size(I), vecProb(I_dark.^2, nd));

% remove anything in signature area

te = and(xe > (1 - sa(1))*size(I, 1), ye > (1 - sa(2))*size(I, 2));
td = and(xd > (1 - sa(1))*size(I, 1), yd > (1 - sa(2))*size(I, 2));
xe(te) = []; xd(td) = [];
ye(te) = []; yd(td) = [];
ne = numel(xe); nd = numel(xd);

%%
x = [xe; xd]; y = [ye; yd];
X = permute([x, y], [1, 3, 2]);
x = X(:, :, 1); y = X(:, :, 2);
D = vecnorm(X - permute(X, [2, 1, 3]), 2, 3);
D = D/max(D(:)); % normalized distances between points

%%
xe(xe > size(I, 1)) = size(I, 1); ye(ye > size(I, 2)) = size(I, 2);
xd(xd > size(I, 1)) = size(I, 1); yd(yd > size(I, 2)) = size(I, 2);

probs = exp(-D*dec);
probs(eye(size(probs)) == 1) = 0;
ii = sub2ind(size(BWs), xe, ye);
jj = sub2ind(size(I), xd, yd);
probs(:, 1:ne) = probs(:, 1:ne) .* BWs(ii)'.^2; % increase odds of moving to a point based on edge-ness
probs(:, ne + 1:end) = probs(:, ne + 1:end) .* (max(I(:)) - I(jj))'; % increase odds of moving to a point based on darkness
A = sum(probs(1:ne, 1:ne), 'all');
B = sum(probs(1:ne, ne+1:end), 'all');
C = sum(probs(ne+1:end, 1:ne), 'all');
D = sum(probs(ne+1:end, ne + 1:end), 'all');

probs(1:ne, 1:ne) = probs(1:ne, 1:ne) * (e2e*(A + B)/A);
probs(ne+1:end, ne + 1:end) = probs(ne+1:end, ne + 1:end)*(d2d*(C + D)/D); % dark to dark
probs = probs ./ sum(probs, 2);

%%
figure(1); clf;
subplot(1, 3, 1)
imshow(I/255); title("Input Image")
subplot(1, 3, 2)
imshow(BWs); title("Edges");
subplot(1, 3, 3)
imshow(ones(size(I))); hold on
plot(ye, xe, 'r.'); hold on
plot(yd, xd, 'k.'); legend('Edge points', 'Dark points'); title("Important Points"); hold off

%%
figure(2)
imshow(ones(gridy*size(I, 1), gridx*size(I, 2))); hold on
for i = 1:gridx
    for j = 1:gridy
        P = probs;
        for d = 1:drawings
            [inds, P] = markov(P, randi([1, nd + ne]), nt, markov_decay);
            t = linspace(0, 1, numel(inds));
            xx = spline(t, x(inds) + noise*(rand(size(inds')) - .5), linspace(0, 1, 50*numel(inds)));
            yy = spline(t, y(inds) + noise*(rand(size(inds')) - .5), linspace(0, 1, 50*numel(inds)));
            figure(2); hold on
            plot((i - 1 + (1-canvas)/2)*size(I, 2) + yy*canvas, (j - 1 + (1-canvas)/2)*size(I, 1) + xx*canvas, ...
                'k-', 'LineWidth', .0001);
        end
        [xs, ys] = signature(.12);
        xs = ((1 - sa(2)) + xs/max(xs)*sa(2));
        ys = (1 - ys/max(ys)*sa(1));
        figure(2); hold on
        plot((i - 1 + (1-canvas)/2)*size(I, 2) + (xs*canvas + (1 - canvas))*canvas*size(I, 2), ...
            (j - 1 + (1-canvas)/2)*size(I, 1) + (ys*canvas + (1 - canvas))*canvas*size(I, 1), ...
            'k-', 'LineWidth', .5); 
    end
end
hold off

function [out, M] = markov(M, i, pts, decay)
out = zeros(1, pts);
for k = 1:pts
    j = vecProb(M(i, :), 1);
    out(k) = j;
    %     M(j, i) = M(j, i)*decay; M(i, j) = M(i, j)*decay;
    M(:, j) = M(:, j)*decay;
    i = j;
end
end

function [xs, ys, x, y] = signature(noise)
t = linspace(0, 2*pi, 100);
x = t + .3*exp(-1*t).*cos(40*t + pi);
y = 2*exp(-3*t) .* ((sin(12*pi*t .*exp(30*t) + pi/2))).^2 + 4*t - 3*t.^2;

assert(numel(x) == numel(y))
xs = spline(t, x + noise*(rand(size(x)) - .5), linspace(0, 1, 50*numel(x)));
ys = spline(t, y + noise*(rand(size(x)) - .5), linspace(0, 1, 50*numel(x)));
xs = xs - min(xs); ys = ys - min(ys);
xs = xs/max(xs); ys = ys/max(ys);
end
