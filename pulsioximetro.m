clear; clc; close all;

% Connect to Arduino
arduino = serialport("COM7", 9600);
disp("Connected. Waiting for data...");
pause(2);

% Parameters
windowLength = 100; % samples to take into account to claulate Spo2
displayWindow = 7; % seconds visible on screen
startTime = tic;

discardN = 15; % number of samples to discard after each LED switch
fs = 20; %Samples are being sent every 50 ms

% Setup figure
figure; hold on;
title('Real-time Pulse Oximetry Signal');
xlabel('Time (s)');
ylabel('Sensor Value');
grid on;

ax = gca;
ax.XColor = [0.2 0.2 0.2];
ax.YColor = [0.2 0.2 0.2];
ax.GridAlpha = 0.3;
ax.FontName = 'Arial';
ax.FontSize = 11;

% Continuous line
signalLine = animatedline('Color',[0.1 0.4 0.8],'LineWidth',1.5);

% SpO₂ text
spo2Text = text(0.02,0.94, 'SpO₂: -- %', 'Units','normalized', 'FontSize',14, 'FontWeight','bold', 'Color',[0.1 0.4 0.8]);

% Label text (just below SpO₂)
signalLabelText = text(0.02,0.88, 'Light: --', 'Units','normalized', 'FontSize',14, 'FontWeight','bold', 'Color',[0.8 0.2 0.2]);

%Heart rate text
heartRateText = text(0.02,0.82,'Heart Rate (bpm): --', 'Units','normalized', 'FontSize',14, 'FontWeight','bold', 'Color',[1 0 1]');
% Pre allocation
redValues = [];
irValues = [];
signalValues = [];
signalTime = [];

% Track LED switches
lastLabel = '';
discardCounter = 0;

% Dynamic axis control
yMin = 0;
yMax = 1023;
autoY = true;

R_data=[];
Spo2_data=[];

% Data acquisition loop
while ishandle(spo2Text)
    if arduino.NumBytesAvailable > 0
        line = strtrim(readline(arduino));  % expect "RED: 00" or "INFRARED: 00"
        intensity_red = regexp(line,'RED brightness calibrated:\s*(\d+)','tokens');
        intensity_ir = regexp(line,'IR brightness calibrated:\s*(\d+)','tokens');
        
        if ~isempty(intensity_red)
            redBrightness = str2double(intensity_red{1}{1});
            fprintf('Red brightness calibrated: %d\n', redBrightness);
        end
        
        if ~isempty(intensity_ir)
            irBrightness = str2double(intensity_ir{1}{1});
            fprintf('Infrared brightness calibrated: %d\n', irBrightness);
        end
        intensity_red=[];
        intensity_ir=[];
        tokens = regexp(line, '(RED|INFRARED):\s*(\d+)', 'tokens');
        if isempty(tokens)
            continue
        end
        label = tokens{1}{1}; % whether red or infrared
        value = str2double(tokens{1}{2});
        t = toc(startTime); % time for plotting

        % Update label text
        set(signalLabelText, 'String', sprintf('Signal: %s', label));

        % Detect LED switch ->  reset discard counter and add vertical line
        if ~strcmp(label,lastLabel)
            discardCounter = discardN;
            lastLabel = label;

            % Add vertical line marker at switch time
            xline(t,'--r','LineWidth',1.2,'Alpha',0.5);
        end

        % Store data
        signalValues(end+1) = value;

        % Moving average 
        N = 3; % window size
        if numel(signalValues) >= N
            smoothVals = filter(ones(1,N)/N, 1, value);
        else
            smoothVals = value;
        end

        if t>0.5
        signalTime(end+1) = t;
        addpoints(signalLine, t, smoothVals);
        drawnow limitrate nocallbacks;
        end

        % Scrolling x-axis
        if t > displayWindow
            xlim([t - displayWindow, t]);
        end

        % Adaptive Y-axis (adjust only when needed)
        if autoY && (value < yMin || value > yMax)
            yMin = min(signalValues);
            yMax = max(signalValues);
            ylim([yMin - 20, yMax + 20]);
            autoY = false;
        end

         % Only add values if discardCounter has expired
        if discardCounter > 0
            discardCounter = discardCounter - 1;
        else
            if strcmp(label,'RED')
                redValues(end+1) = value;
                if numel(redValues) > windowLength
                    redValues = redValues(end-windowLength+1:end);
                end
            elseif strcmp(label,'INFRARED')
                irValues(end+1) = value;
                if numel(irValues) > windowLength
                    irValues = irValues(end-windowLength+1:end);
                end
            end
        end
        

 % Compute SpO₂
if numel(redValues) >= 75 && numel(irValues) >= 75
    %Band pass filter 0.5-5 Hz
    [b,a] = butter(2,[0.5 5]/(fs/2));
    rv_ac = filtfilt(b,a, redValues - mean(redValues));
    iv_ac = filtfilt(b,a, irValues - mean(irValues));

    AC_red = sqrt(mean(rv_ac.^2));
    AC_ir  = sqrt(mean(iv_ac.^2));
    DC_red = mean(redValues);
    DC_ir  = mean(irValues);

    R = log10(AC_red/DC_red) / log10(AC_ir/DC_ir);
    
    R_data(end+1) = R; % Store the computed R value for further analysis


    %Only calculate spo2 if there is a pulse (pulsatile amplitude has to
    %be at least 30)
    if AC_ir<30 && AC_red<30
       
        set(spo2Text,'String',sprintf('SpO₂: No pulse'));
    else
        Spo2 = 99.68 + 6.94*R + -15.33*R^2;
        set(spo2Text,'String',sprintf('SpO₂: %.1f %%',Spo2));
    end
    
    %Calulate heart rate every 5 seconds
    if numel(redValues)==100 
        %Derivative of irValues
        redDerivative = gradient(redValues);        
        %Filter derivative
        filteredDerivative = smoothdata(redDerivative, 'movmean', 5);
        %Find peaks    
        [peaks, locs] = findpeaks(filteredDerivative, 'MinPeakHeight', 10,'MinPeakDistance',0.5*fs);
        %Heart rate is the number of peaks divided by 5 seconds (time for 100
        %samples)
        heartRate1=numel(peaks)*60/5;
        % Update heart rate text
        set(heartRateText, 'String', sprintf('Heart Rate (bpm): %d', round(heartRate1)));
    end
end
    end
end
