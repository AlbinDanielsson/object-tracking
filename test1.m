clear all
clc

r1 = 10;
r2 = 20;
l = 5;

angle = flatObjectAngle(r1, r2, l);


d = flatObjectDistance(r1, r2);

e1 = closestPointOnPlane(angle, r1);
e2 = closestPointOnPlane(angle, r2);

t = cos (angle);
angle = angle * (180 / pi);

