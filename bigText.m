clear;
clc;
close all;

% Skapa fönster
fig = figure( ...
    'Color', 'white', ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'NumberTitle', 'off', ...
    'Name', 'Random Numbers');

ax = axes(fig);
axis(ax, [0 1 0 1]);
axis(ax, 'off');

% Stor text mitt på skärmen
txt = text(0.5, 0.5, '', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 120, ...
    'FontWeight', 'bold');

for i = 1:20

    % Två slumpmässiga tal 0-99
    n1 = randi([0 99]);
    n2 = randi([0 99]);

    % Var fjärde iteration: röd text och 4 s paus
    if mod(i,4) == 0
        txt.Color = 'red';
        pauseTime = 4;
    else
        txt.Color = 'black';
        pauseTime = 0.5;
    end

    txt.String = sprintf('%02d   %02d', n1, n2);

    drawnow;
    pause(pauseTime);
end