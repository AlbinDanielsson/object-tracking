function r = expectedSensorReading(X, sensorX, objectWidth, maxRange, sensorEA)
    
    X = X';
    MaxAngle = pi/6;

    if X(3) > MaxAngle || X(3) < -MaxAngle
        r = maxRange;
        return
    end

    %Angle to closest point if width was inf
    angleToClosest = X(3) + pi/2;
    s = [sensorX; 0];

    %Get endpoints
    delta = [(objectWidth/2) * cos(X(3)); (objectWidth/2) * sin(X(3))];
    epL = X(1:2)' - delta; %left
    epR = X(1:2)' + delta; %right

    %Get the angles to the endpoints
    aEpL = atan2(epL(1) - s(1), epL(2) - s(2)) + pi/2;
    aEpR = atan2(epR(1) - s(1), epR(2) - s(2)) + pi/2;

    %See where scope boundaries cross the object, with inf len
    leftScopeBoundaryAngle = pi/2 + sensorEA/2; %90 + 1 degree
    rightScopeBoundaryAngle = pi/2 - sensorEA/2;
    dO = [cos(X(3)); sin(X(3))];
    dL = [cos(leftScopeBoundaryAngle); sin(leftScopeBoundaryAngle)];
    dR = [cos(rightScopeBoundaryAngle); sin(rightScopeBoundaryAngle)];
    tr = det([s-X(1:2)', dR]) / det([dO, dR]);
    tl = det([s-X(1:2)', dL]) / det([dO, dL]);
    leftBP = X(1:2)' + tl*dO;
    rightBP = X(1:2)' + tr*dO;
    %aLBp = atan2(leftBP(1) - s(1), leftBP(2) - s(2)); %Angle to that boundary point
    %aRBp = atan2(rightBP(1) - s(1), rightBP(2) - s(2));

    %if whole object is out of bounds, return maxRange
    %if aEpL < aRBp || aEpR > aLBp
    if (aEpL > pi/2 + sensorEA/2 && aEpR > pi/2 + sensorEA/2) || (aEpL < pi/2 - sensorEA/2 && aEpR < pi/2 - sensorEA/2)
        r = maxRange;
        return;
    end

    %if end point is out of bounds and BP's are close enough to center
    %move ep to BP
    if aEpL > pi/2 + sensorEA/2
        aEpL = pi/2 + sensorEA/2;
        epL = leftBP;
    elseif aEpL < pi/2 - sensorEA/2
        aEpL = pi/2 - sensorEA/2;
        epL = rightBP;
    end
    if aEpR > pi/2 + sensorEA/2
        aEpR = pi/2 + sensorEA/2;
        epR = leftBP;
    elseif aEpR < pi/2 - sensorEA/2
        aEpR = pi/2 - sensorEA/2;
        epR = rightBP;
    end

    %See if the line from the sensor intercepts the object
    closestPoint = [0; 0];

    if angleToClosest < aEpR && angleToClosest > aEpL
        %Set closest point to the intersection from angle to closest
        dS = [cos(angleToClosest); sin(angleToClosest)];
        t = det([s-X(1:2)', dS]) / det([dO, dS]);
        closestPoint = X(1:2)' + t*dO;

    elseif angleToClosest > aEpL
        closestPoint = epL;

    elseif angleToClosest < aEpR
        closestPoint = epR;
    end

    r = norm(closestPoint - s);
end