function y = triangle(r1, r2, l)
    %from equations
    y = [0, 0];
    y(1) = (r1^2 - r2^2)/(2*l);
    y(2) = sqrt(r1^2 - (y(1) + 0.5 * l)^2);
end