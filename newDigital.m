clear; clc; close all;

myDaq = daq("ni");

%Digital trigger outputs
addoutput(myDaq, "myDAQ1", "port0/line0", "Digital");
addoutput(myDaq, "myDAQ1", "port0/line3", "Digital");
addoutput(myDaq, "myDAQ1", "port0/line6", "Digital");

%Digital input
addinput(myDaq, "myDAQ1", "port0/line1", "Digital");
%addinput(myDaq, "myDAQ1", "port0/line4", "Digital");
%addinput(myDaq, "myDAQ1", "port0/line7", "Digital");

%Initialize output
write(myDaq, false);

duration = 150;
pauseLen = 1;

triggerOne = repmat([1 0 0], 1, 50);
triggerTwo = repmat([0 1 0], 1, 50);
triggerThree = repmat([0 0 1], 1, 50);

for i = 1:1:duration
    pause(pauseLen);

    write(myDaq, [triggerOne(i), triggerTwo(i), triggerThree(i)]);

    in = read(myDaq, "OutputFormat", "matrix");
    inputState = in(1);
    disp("Input state: " + inputState);
end

write(myDaq, false);