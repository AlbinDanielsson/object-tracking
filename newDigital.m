clear; clc; close all;

myDaq = daq("ni");

% Digital trigger output
addoutput(myDaq, "myDAQ1", "port0/line0", "Digital");

% Digital input
addinput(myDaq, "myDAQ1", "port0/line1", "Digital");

% Initialize output LOW
write(myDaq, false);

while true
    pause(1);

    % Set output HIGH
    write(myDaq, true);

    % Read input (matrix format for older MATLAB versions)
    in = read(myDaq, "OutputFormat", "matrix");
    inputState = in(1);  % first input channel

    disp("Input state: " + inputState);

    pause(1);

    % Set output LOW
    write(myDaq, false);

    % Read again
    in = read(myDaq, "OutputFormat", "matrix");
    inputState = in(1);

    disp("Input state: " + inputState);
end

% This line will never be reached, but kept for safety
write(myDaq, false);