clear; clc; close all;

myDaq = daq("ni");

%Digital trigger outputs
addoutput(myDaq, "myDAQ1", "port0/line0", "Digital");
addoutput(myDaq, "myDAQ1", "port0/line3", "Digital");
addoutput(myDaq, "myDAQ1", "port0/line6", "Digital");

%Digital input
addinput(myDaq, "myDAQ1", "port0/line1", "Digital");
addinput(myDaq, "myDAQ1", "port0/line4", "Digital");
addinput(myDaq, "myDAQ1", "port0/line7", "Digital");

idleLen = 30;
pauseLen = 0.00001;

idle = zeros(1, idleLen);

triggerOne = repmat(idle, 1, 3);
triggerOne(1) = 1;
triggerTwo = repmat(idle, 1, 3);
triggerTwo(idleLen + 1) = 1;
triggerThree = repmat(idle, 1, 3);
triggerTwo(2 * idleLen + 1) = 1;

while true
    for i = 1:1:numel(triggerOne)
        pause(pauseLen);

        write(myDaq, [triggerOne(i), triggerTwo(i), triggerThree(i)]);

        in = read(myDaq, "OutputFormat", "matrix");
        fprintf("Input state: %.1f %.1f %.1f \n", in(1), in(2), in(3));
    end
end