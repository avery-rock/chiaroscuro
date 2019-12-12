function someFunction
    % create our clean up object
    cleanupObj = onCleanup(@cleanMeUp);
    % load an image, create some variables
    I = imread('dannydevito.jpg');
    Z = zeros(42,24,42);
    U = ones(1,2,3);
    keepGoing = true;
    while keepGoing
        % do our work
        % add a 100 msec pause
        pause(0.01);
    end
    % fires when main function terminates
    function cleanMeUp()
        % saves data to file (or could save to workspace)
        fprintf('saving variables to file...\n');
        filename = [datestr(now,'yyyy-mm-dd_HHMMSS') '.mat'];
        save(filename,'I','Z','U');
    end
 end