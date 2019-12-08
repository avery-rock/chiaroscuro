% close all; clear all; clc;
function [outx, outy] = drawme2(I, plt, sig)

outx = {}; outy = {}; 

% PARAMETERS
int_pts = 10; 
shading_visits = 1;
markov_decay = .7;
gridx = 1;
gridy = 1;
canvas = .98;
noise = 3;
dec = 100;
edr = 2; 
ddr = 15;
sa = [(1 - canvas)/3, .25]; % signature area
edge_step = 5;
pix_const = 5;
dark_bins = [.1 .3 .6]; 
shading_densities = (1 - dark_bins + min(dark_bins)).^2; shading_densities = shading_densities / max(shading_densities); 
canny_size = 6; 

sig_color = [0 0 0]; 

% LOAD IMAGE
% I = imread('input_images/black.jpg');
I = imresize(I, 1000/size(I, 1));
I = double(rgb2gray(I));

% EDGE DETECTION
BWs = edge(I, 'canny', [], canny_size);
BWs(:, end) = 0; BWs(end, :) = 0; BWs(1, :) = 0; BWS(:, 1) = 0; % make borders all zeros.
[labels, n] = bwlabel(BWs);
h = [-.5 -1 -.5; -1 2 -1; -.5, -1, -.5];
e = imfilter(BWs, h); % end points of edges
BWs(e < -1) = 0;
e = e >= .5;

edges = cell(n, 2);
for ed = 1:n
    if nnz(e(labels == ed)) % if that edge has two valid end points
        [xe, ye] = find(labels.*e == ed, 1, 'last');
        [X, Y] = edgeStep(labels == ed, xe, ye, edge_step);
        edges(ed, 1) = {X}; edges(ed, 2) = {Y};
    end
end

% DARK CLUSTERS

h = fspecial('gaussian', 9, 3); 
I = imfilter(I, h, 'replicate'); 
[c, b] = imhist(I/255);
imq = imquantize(I, dark_bins*max(I(:))); 
darks = cell([], 2); 
for bin = 1:numel(dark_bins)
[dlabels, dcount] = bwlabel(imq == bin);
dark_cat = cell(dcount, 2);
for d = 1:dcount
    if nnz(dlabels == d) > numel(I)*5e-4
        [xd, yd] = ind2sub(size(I), vecProb(dlabels(:) == d, ceil(pix_const*shading_densities(bin)*sqrt(nnz(dlabels == d)))));
        xd(xd > size(I, 1)) = size(I, 1); yd(yd > size(I, 2)) = size(I, 2);
        dark_cat{d, 1} = xd; dark_cat{d, 2} = yd;
    end
end
darks = [darks; dark_cat]; 
end

%% represent image processing
if plt
figure(1); clf;
subplot(1, 3, 1)
imshow(I/255); title("Input Image")
subplot(1, 3, 2)
imshow(BWs); title("Edges");
subplot(1, 3, 3)
imshow(double(imq)/max(imq(:))); title("Posterized Image");
end

%%
if plt
figure(2)
imshow(ones(gridy*size(I, 1), gridx*size(I, 2))); hold on
end
for i = 1:gridx
    for j = 1:gridy
        for e = 1:size(edges, 1)
            xe = edges{e, 1}; ye = edges{e, 2};
            if numel(xe) >= 2
                t = linspace(0, 1, numel(xe));
                for dr = 1:edr
                xx = spline(t, xe + noise*(rand(size(xe)) - .5), linspace(0, 1, int_pts*numel(xe)));
                yy = spline(t, ye + noise*(rand(size(ye)) - .5), linspace(0, 1, int_pts*numel(xe)));
                
                outx = [outx; xx]; % concatenate new path points to old
                outy = [outy; yy]; 
                
                if plt
                figure(2); hold on
                plot((i - 1 + (1-canvas)/2)*size(I, 2) + yy*canvas, (j - 1 + (1-canvas)/2)*size(I, 1) + xx*canvas, ...
                    'k-', 'LineWidth', .0001); 
                hold on
                end
                end
            end
        end
        for d = 1:size(darks, 1)
            xd = darks{d, 1};
            yd = darks{d, 2};
            if numel(xd) > 2
                X = permute([xd, yd], [1, 3, 2]);
                D = vecnorm(X - permute(X, [2, 1, 3]), 2, 3);
                D = D/max(D(:)); % normalized distances between points
                P = exp(-D*dec);
                P(eye(size(P)) == 1) = 0;
                for dr = 1:ddr
                    [inds, P] = markov(P, randi([1, numel(xd)]), shading_visits * numel(xd), markov_decay);
                    t = linspace(0, 1, numel(inds));
                    xx = spline(t, xd(inds) + noise*(rand(size(inds')) - .5), linspace(0, 1, int_pts*numel(inds)));
                    yy = spline(t, yd(inds) + noise*(rand(size(inds')) - .5), linspace(0, 1, int_pts*numel(inds)));
                    outx = [outx; xx]; % concatenate new path points to old
                    outy = [outy; yy];
                    if plt
                    figure(2); hold on
                    plot((i - 1 + (1-canvas)/2)*size(I, 2) + yy*canvas, (j - 1 + (1-canvas)/2)*size(I, 1) + xx*canvas, ...
                        'k-', 'LineWidth', .0001);
                    end
                end
            end
        end
        if sig
        [xs, ys] = signature(.12);
        xs = canvas*((1 - sa(2)) + xs/max(xs)*sa(2)) + (1 - canvas)/2;
        ys = (1 - ys/max(ys)*sa(1));
        outx = [outx; xs]; % concatenate new path points to old
        outy = [outy; ys]; % concatenate new path points to old
        if plt
        figure(2); hold on
        plot((i - 1)*size(I, 2) + (xs)*size(I, 2), ...
            (j - 1)*size(I, 1) + (ys)*size(I, 1), ...
            '-', 'LineWidth', 1, 'Color', sig_color);
        end
        end
    end
end
hold off

end

function [xs, ys, x, y] = signature(noise)
t = linspace(0, 2*pi, 50);
x = t + .3*exp(-1*t).*cos(40*t + pi);
y = 2*exp(-3*t) .* ((sin(12*pi*t .*exp(30*t) + pi/2))).^2 + 4*t - 3*t.^2;

assert(numel(x) == numel(y))
xs = spline(t, x + noise*(rand(size(x)) - .5), linspace(0, 1, 50*numel(x)));
ys = spline(t, y + noise*(rand(size(x)) - .5), linspace(0, 1, 50*numel(x)));
xs = xs - min(xs); ys = ys - min(ys);
xs = xs/max(xs); ys = ys/max(ys);
end

function [X, Y] = edgeStep(BW, x, y, n)
len = ceil(nnz(BW)/n); % approx steps
X = zeros(1, len); Y = zeros(1, len); % preallocate
for s = 1:len
    i = 0;
    while i < n
        i = i + 1;
        BW(x, y) = 0;
        [a, b] = find(BW(x-1:x+1, y-1:y+1), 1);
        if isempty(a)
            X(X == 0) = []; Y(Y == 0) = [];
            return
        end
        x = x + a - 2; y = y + b - 2;
    end
    X(s) = x; Y(s) = y;
end
end

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