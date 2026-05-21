clc, clear all
l = 15.4; %cm

objectWidth = 0.5; %m
    objectCenter = [0, 3];%m
    objectAngle = 0;%rads

figure;
hold on;
axis equal;
xlim([-1 1]);
ylim([0 4]);

%Checkerboard
squareSize = 0.5;
xEdges = -2:squareSize:2;
yEdges = 0:squareSize:4;
for i = 1:length(xEdges)-1
    for j = 1:length(yEdges)-1
        if mod(i+j,2) == 0
            shade = 0.75;
        else
            shade = 0.9;
        end
        rectangle( ...
            'Position', [xEdges(i), yEdges(j), squareSize, squareSize], ...
            'FaceColor', [shade shade shade], ...
            'EdgeColor', 'none');
    end
end

%Sensors
plot(l/200, 0, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 8);
plot(-l/200, 0, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 8);
xlabel('x');
ylabel('y');
box on;
xSensor = [l/200, -l/200];
ySensor = [0, 0];
for k = 1:length(xSensor)

    % Left and right cone boundary slopes
    dx = 4 * tand(7.5);

    xLeft  = xSensor(k) - dx;
    xRight = xSensor(k) + dx;

    % Shade sensor field of view
    if k == 1
        coneColor = [1 0 0];   % red
    else
        coneColor = [0 1 0];   % green
    end

    patch( ...
        [xSensor(k), xLeft, xRight], ...
        [0,          4,     4], ...
        coneColor, ...
        'FaceAlpha', 0.25, ...
        'EdgeColor', 'none');

    % Draw cone boundary lines up to y = 4
    plot([xSensor(k), xLeft],  [0, 4], 'k-', 'LineWidth', 1);
    plot([xSensor(k), xRight], [0, 4], 'k-', 'LineWidth', 1);
end

%% 

% Initial object endpoints
xObj = [objectCenter(1) - cos(objectAngle)*objectWidth/2, ...
        objectCenter(1) + cos(objectAngle)*objectWidth/2];

yObj = [objectCenter(2) - sin(objectAngle)*objectWidth/2, ...
        objectCenter(2) + sin(objectAngle)*objectWidth/2];

% Create object once
hObj = plot(xObj, yObj, 'color', 'blue', 'LineWidth', 3);

%Remove
arbitraryTraj = [zeros(1, 1000); 3:-3/999:0];

for i = 1:1000
    %replace this
    %objectCenter = arbitraryTraj(:, i);
    %objectAngle = objectAngle + pi/400;

    %Plot object
    xObj = [objectCenter(1) - cos(objectAngle)*objectWidth/2, ...
            objectCenter(1) + cos(objectAngle)*objectWidth/2];
    yObj = [objectCenter(2) - sin(objectAngle)*objectWidth/2, ...
            objectCenter(2) + sin(objectAngle)*objectWidth/2];
    set(hObj, 'XData', xObj, 'YData', yObj);
    drawnow
end

