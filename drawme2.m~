% close all; clear all; clc;
function [outx, outy, xscale, yscale] = drawme2(I)

outx = {}; outy = {}; % initialize empty cell arrays for line segments.
plt = 1; sig = 0; 

% OVERALL PARAMETERS
imsize = 500; % maximum pixel dimensions of image
int_pts = 2; % intermediate points for splines
noise = 1*(imsize/100); % percent error to points.

% SHADING PARAMATERS
shading_drawings = 3; % number of times to repeat drawings
shading_visits = 1; % multiple of the number of total points in a sample to visit during a single drawing
markov_decay = .6; % factor for decreasing loop duration
dec = 30; % exponential rate for random walk probabilities. 0 = uniform. 
pix_const = 3; % scaling factor for subsampling. Higher values sample more points
dark_bins = [.1 .4]; % threshold values for posterization
shading_densities = (1 - dark_bins).^2; shading_densities = shading_densities / max(shading_densities);

% EDGE PARAMETERS
edge_drawings = 1; % number of edge copies to draw (2 recommended)
edge_step = imsize/100; % pixels between waypoints on edges. 
canny_size = imsize/100;

% SIGNATURE PARAMETERS
canvas = 1; % drawing position within workspace. 1 fills it completely. 
sa = [(1 - canvas)/3, .25]; % signature area

% RESIZE AND NORMALIZE IMAGE
I = imresize(I, imsize/size(I, 1)); 
A = I; % save color version
xscale = size(I, 1); yscale = size(I, 2); scale = max(xscale, yscale); % save image dimensions
I = double(rgb2gray(I)); % make image bw
I = (I - min(I(:)))/(max(I(:)) - min(I(:))); % normalize the image

% EDGE DETECTION
edge_clusters = edge(I, 'canny', [], canny_size); % find all strong edges
edge_clusters(:, end) = 0; 
edge_clusters(end, :) = 0; 
edge_clusters(1, :) = 0; 
edge_clusters(:, 1) = 0; % make borders all zeros.

[labels, n] = bwlabel(edge_clusters); % find all edge clusters
h = [-.5 -1 -.5; -1 2 -1; -.5, -1, -.5]; % custom filter to find ends of line segments
e = imfilter(edge_clusters, h); % end points of edges
edge_clusters(e < -1) = 0; e = e >= .5;

edges = cell(n, 2);
for ed = 1:n % for each edge
    if nnz(e(labels == ed)) % if that edge has two valid end points
        [xe, ye] = find(labels.*e == ed, 1, 'last'); % find the highest-indexed end
        [X, Y] = edgeStep(labels == ed, xe, ye, edge_step); % walk along edge
        edges(ed, 1) = {X}; edges(ed, 2) = {Y}; % save waypoints
    end
end

% DARK CLUSTERS
h = fspecial('gaussian', 9, 3); 
I = imfilter(I, h, 'replicate'); % smooth out image
% [c, b] = imhist(I/255); % use histogram for automatic thresholding. 
imq = imquantize(I, dark_bins*max(I(:)));
dark_clusters = cell([], 2);
for bin = 1:numel(dark_bins)
    [dlabels, dcount] = bwlabel(imq == bin);
    dark_cluster = cell(dcount, 2);
    for d = 1:dcount
        if nnz(dlabels == d) > numel(I)*5e-4
            [xd, yd] = ind2sub(size(I), vecProb(dlabels(:) == d, ceil(pix_const*shading_densities(bin)*sqrt(nnz(dlabels == d)))));
            xd(xd > size(I, 1)) = size(I, 1); yd(yd > size(I, 2)) = size(I, 2);
            dark_cluster{d, 1} = xd; dark_cluster{d, 2} = yd;
        end
    end
    dark_clusters = [dark_clusters; dark_cluster];
end

%% represent image processing
if plt
    figure();
    subplot(1, 3, 1)
    imshow(A); title("Input Image")
    subplot(1, 3, 2)
    imshow(edge_clusters); title("Edges");
    subplot(1, 3, 3)
    imshow(double(imq)/max(imq(:))); title("Posterized Image");
end

for e = 1:size(edges, 1)
    xe = edges{e, 1}; ye = edges{e, 2};
    if numel(xe) >= 2
        t = linspace(0, 1, numel(xe));
        for dr = 1:edge_drawings
            xx = spline(t, xe + noise*(rand(size(xe)) - .5), linspace(0, 1, int_pts*numel(xe)));
            yy = spline(t, ye + noise*(rand(size(ye)) - .5), linspace(0, 1, int_pts*numel(xe)));
            outx = [outx; (-xx)/scale]; % concatenate new path points to old
            outy = [outy; (yy)/scale];     
        end
    end
end

% COMPUTE PROBABILITIES
for d = 1:size(dark_clusters, 1)
    xd = dark_clusters{d, 1};
    yd = dark_clusters{d, 2};
    if numel(xd) > 100
        X = permute([xd, yd], [1, 3, 2]);
        D = vecnorm(X - permute(X, [2, 1, 3]), 2, 3); 
        D = D/max(D(:)); % normalized distances between points
        P = exp(-D*dec); % compute exponentially decreasing probability of going from one point to all other points
        P(eye(size(P)) == 1) = 0; % force points never to go to themselves
        for dr = 1:shading_drawings
            [inds, P] = markov(P, randi([1, numel(xd)]), shading_visits * numel(xd), markov_decay);
            t = linspace(0, 1, numel(inds));
            xx = spline(t, xd(inds) + noise*(rand(size(inds')) - .5), linspace(0, 1, int_pts*numel(inds)));
            yy = spline(t, yd(inds) + noise*(rand(size(inds')) - .5), linspace(0, 1, int_pts*numel(inds)));
            outx = [outx; (-xx)/scale]; % concatenate new path points to old
            outy = [outy; (yy)/scale];  
        end
    end
end

if sig % add signature
    [xs, ys] = signature(.12);
    xs = canvas*((1 - sa(2)) + xs/max(xs)*sa(2)) + (1 - canvas)/2;
    ys = (1 - ys/max(ys)*sa(1));
    outx = [outx; (-xs)/scale]; % concatenate new path points to old
    outy = [outy; (ys)/scale];
end

for i = numel(outx):-1:1
    if numel(outx{i}) < 8
        outx(i) = []; outy(i) = []; 
    end
end

xscale = xscale / scale; yscale = yscale / scale; % normalize scales for return

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
% Computes a random walk between indices of a sparse matrix M, starting at
% index i, until a total of pts steps have been taken. Optional parameter
% decay multiplies the odds of visiting a given point by that factor after
% it has been visited. 
if nargin == 3 || decay > 1
    decay = 1; 
end
out = zeros(1, pts);
for k = 1:pts
    j = vecProb(M(i, :), 1);
    out(k) = j;
    M(:, j) = M(:, j)*decay;
    i = j;
end

end

function [xs, ys, x, y] = signature(noise)
% Makes a signature path for Chiaroscuro


end