function run_all_simulations()
%RUN_ALL_SIMULATIONS Generate reproducible MATLAB simulation results.
% All outputs are written under ../output and are used by the report builder.

clc;
close all;
format long g;
rng(20260607, 'twister');

matlabRoot = fileparts(mfilename('fullpath'));
projectRoot = fileparts(matlabRoot);
outputRoot = fullfile(projectRoot, 'output');
resultsDir = fullfile(outputRoot, 'results');
figuresDir = fullfile(outputRoot, 'figures');
logsDir = fullfile(outputRoot, 'logs');
modelsDir = fullfile(projectRoot, 'models');

ensureDir(outputRoot);
ensureDir(resultsDir);
ensureDir(figuresDir);
ensureDir(logsDir);
ensureDir(modelsDir);

logPath = fullfile(logsDir, 'matlab_run.log');
if exist(logPath, 'file')
    delete(logPath);
end
diary(logPath);
diary on;

cleanupObj = onCleanup(@() diary('off'));

fprintf('MATLAB simulation run started: %s\n', datestr(now, 31));
fprintf('Project root: %s\n', projectRoot);
fprintf('MATLAB version: %s\n', version);

toolboxInfo = captureToolboxes();
writeText(fullfile(logsDir, 'toolboxes.txt'), toolboxInfo);
fprintf('Toolbox inventory written to output/logs/toolboxes.txt\n');

params = defaultParams();
writeJson(fullfile(resultsDir, 'simulation_parameters.json'), params);

fprintf('\n[1/5] Motor control simulation...\n');
motor = simulateMotorControl(params.motor);
writetable(motor.series, fullfile(resultsDir, 'motor_response.csv'), 'Encoding', 'UTF-8');
writeJson(fullfile(resultsDir, 'motor_summary.json'), motor.summary);
plotMotorResults(motor.series, motor.summary, figuresDir);

fprintf('\n[2/5] Video capture/link simulation...\n');
video = simulateVideoLink(params.video);
writetable(video.series, fullfile(resultsDir, 'video_buffer.csv'), 'Encoding', 'UTF-8');
writeJson(fullfile(resultsDir, 'video_summary.json'), video.summary);
plotVideoResults(video.series, video.summary, figuresDir);

fprintf('\n[3/5] RF link simulation...\n');
rf = simulateRfLink(params.rf);
writetable(rf.budget, fullfile(resultsDir, 'rf_link_budget.csv'), 'Encoding', 'UTF-8');
writetable(rf.berCurve, fullfile(resultsDir, 'rf_ber_curve.csv'), 'Encoding', 'UTF-8');
writeJson(fullfile(resultsDir, 'rf_summary.json'), rf.summary);
plotRfResults(rf.budget, rf.berCurve, rf.summary, figuresDir);

fprintf('\n[4/5] System diagrams...\n');
drawSystemDiagrams(figuresDir);

fprintf('\n[5/5] Simulink model generation...\n');
simulinkStatus = createSimulinkModel(modelsDir);
writeJson(fullfile(resultsDir, 'simulink_model_status.json'), simulinkStatus);

summary = struct();
summary.generated_at = datestr(now, 31);
summary.matlab_version = version;
summary.motor = motor.summary;
summary.video = video.summary;
summary.rf = rf.summary;
summary.simulink = simulinkStatus;
summary.outputs = struct( ...
    'motor_csv', normalizePath(fullfile(resultsDir, 'motor_response.csv')), ...
    'video_csv', normalizePath(fullfile(resultsDir, 'video_buffer.csv')), ...
    'rf_budget_csv', normalizePath(fullfile(resultsDir, 'rf_link_budget.csv')), ...
    'rf_ber_csv', normalizePath(fullfile(resultsDir, 'rf_ber_curve.csv')), ...
    'figures_dir', normalizePath(figuresDir), ...
    'logs_dir', normalizePath(logsDir));
writeJson(fullfile(resultsDir, 'simulation_summary.json'), summary);

fprintf('\nSimulation run completed: %s\n', datestr(now, 31));
fprintf('Summary written to output/results/simulation_summary.json\n');
end

function params = defaultParams()
params = struct();

params.motor = struct();
params.motor.sample_time_s = 5e-4;
params.motor.stop_time_s = 2.5;
params.motor.dc_bus_v = 24.0;
params.motor.armature_resistance_ohm = 0.8;
params.motor.armature_inductance_h = 3.5e-3;
params.motor.torque_constant_nm_per_a = 0.25;
params.motor.back_emf_v_per_radps = 0.18;
params.motor.rotor_inertia_kgm2 = 0.008;
params.motor.viscous_friction_nms = 0.02;
params.motor.current_limit_a = 15.0;
params.motor.target_speed_rpm = 600.0;
params.motor.reverse_time_s = 1.20;
params.motor.load_step_time_s = 0.75;
params.motor.load_torque_nm = 0.10;
params.motor.pid_kp = 0.12;
params.motor.pid_ki = 3.20;
params.motor.pid_kd = 0.0010;

params.video = struct();
params.video.duration_s = 20.0;
params.video.frame_rate_fps = 25.0;
params.video.width_px = 1280;
params.video.height_px = 720;
params.video.raw_bits_per_pixel = 24;
params.video.mean_payload_mbps = 36.0;
params.video.rf_capacity_mbps = 42.0;
params.video.capacity_jitter_mbps = 5.2;
params.video.buffer_capacity_mb = 32.0;
params.video.initial_buffer_mb = 4.0;
params.video.control_overhead_mbps = 0.35;

params.rf = struct();
params.rf.distance_km = 10.0;
params.rf.frequencies_mhz = [40.0, 100.0, 200.0];
params.rf.tx_power_control_dbm = 30.0;
params.rf.tx_power_video_dbm = 37.0;
params.rf.tx_antenna_gain_dbi = 3.0;
params.rf.rx_antenna_gain_dbi = 3.0;
params.rf.total_cable_loss_db = 2.0;
params.rf.noise_figure_db = 4.0;
params.rf.control_bandwidth_hz = 25e3;
params.rf.video_bandwidth_hz = 6e6;
params.rf.control_bitrate_bps = 9.6e3;
params.rf.video_bitrate_bps = 36e6;
params.rf.ber_bits = 120000;
params.rf.ber_ebn0_db = 0:2:14;
end

function motor = simulateMotorControl(p)
dt = p.sample_time_s;
t = (0:dt:p.stop_time_s)';
n = numel(t);

speed = zeros(n, 1);
current = zeros(n, 1);
voltage = zeros(n, 1);
duty = zeros(n, 1);
target = zeros(n, 1);
loadTorque = zeros(n, 1);
pidError = zeros(n, 1);

omega = 0.0;
iArm = 0.0;
integral = 0.0;
prevError = 0.0;

targetRad = p.target_speed_rpm * 2*pi / 60.0;
for k = 1:n
    if t(k) < p.reverse_time_s
        target(k) = targetRad;
    else
        target(k) = -targetRad;
    end
    if t(k) >= p.load_step_time_s
        loadTorque(k) = p.load_torque_nm * signOrOne(omega);
    end

    error = target(k) - omega;
    integral = integral + error * dt;
    derivative = (error - prevError) / dt;
    vCmd = p.pid_kp * error + p.pid_ki * integral + p.pid_kd * derivative;
    vSat = min(max(vCmd, -p.dc_bus_v), p.dc_bus_v);

    if abs(iArm) > p.current_limit_a
        vSat = 0.85 * vSat;
    end
    if abs(vCmd - vSat) > 1e-9
        integral = integral - error * dt * 0.35;
    end

    di = (vSat - p.armature_resistance_ohm*iArm - p.back_emf_v_per_radps*omega) ...
        / p.armature_inductance_h;
    iArm = iArm + di * dt;
    iArm = min(max(iArm, -p.current_limit_a), p.current_limit_a);

    domega = (p.torque_constant_nm_per_a*iArm - p.viscous_friction_nms*omega - loadTorque(k)) ...
        / p.rotor_inertia_kgm2;
    omega = omega + domega * dt;

    speed(k) = omega * 60.0 / (2*pi);
    current(k) = iArm;
    voltage(k) = vSat;
    duty(k) = abs(vSat) / p.dc_bus_v;
    pidError(k) = error * 60.0 / (2*pi);
    prevError = error;
end

targetRpm = target * 60.0 / (2*pi);
series = table(t, targetRpm, speed, current, voltage, duty, loadTorque, pidError, ...
    'VariableNames', {'time_s','target_speed_rpm','speed_rpm','current_a','voltage_v','pwm_duty','load_torque_nm','speed_error_rpm'});

preReverse = t < p.reverse_time_s;
positiveTarget = p.target_speed_rpm;
riseIndex = find(speed >= 0.9 * positiveTarget & preReverse, 1, 'first');
if isempty(riseIndex)
    riseTime = NaN;
else
    riseTime = t(riseIndex);
end
maxPreReverse = max(speed(preReverse));
overshoot = max(0, (maxPreReverse - positiveTarget) / positiveTarget * 100.0);
steadyWindow = t > 0.95 & t < 1.15;
steadyError = mean(abs(speed(steadyWindow) - positiveTarget));
postReverseWindow = t > 1.75;
reverseError = mean(abs(speed(postReverseWindow) + positiveTarget));

summary = struct();
summary.sample_time_s = dt;
summary.stop_time_s = p.stop_time_s;
summary.target_speed_rpm = positiveTarget;
summary.reverse_time_s = p.reverse_time_s;
summary.load_step_time_s = p.load_step_time_s;
summary.load_torque_nm = p.load_torque_nm;
summary.rise_time_90_s = riseTime;
summary.overshoot_percent = overshoot;
summary.steady_speed_error_rpm = steadyError;
summary.reverse_steady_error_rpm = reverseError;
summary.max_current_a = max(abs(current));
summary.max_pwm_duty = max(duty);
summary.final_speed_rpm = speed(end);

motor = struct('series', series, 'summary', summary);
fprintf('Motor: rise90=%.4fs, overshoot=%.2f%%, steady error=%.2frpm, final=%.2frpm\n', ...
    riseTime, overshoot, steadyError, speed(end));
end

function video = simulateVideoLink(p)
dt = 1.0 / p.frame_rate_fps;
t = (0:dt:p.duration_s)';
n = numel(t);

rawMbps = p.width_px * p.height_px * p.raw_bits_per_pixel * p.frame_rate_fps / 1e6;
payloadMbps = zeros(n, 1);
capacityMbps = zeros(n, 1);
bufferMb = zeros(n, 1);
latencyMs = zeros(n, 1);
dropFlag = zeros(n, 1);

buffer = p.initial_buffer_mb * 8.0;
capacityMb = p.buffer_capacity_mb * 8.0;
for k = 1:n
    sceneFactor = 1.0 + 0.12*sin(2*pi*0.35*t(k)) + 0.05*randn();
    payloadMbps(k) = max(20.0, p.mean_payload_mbps * sceneFactor);
    fade = 0.72 + 0.28*sin(2*pi*0.08*t(k) + 0.6)^2;
    capacityMbps(k) = max(25.0, p.rf_capacity_mbps * fade + p.capacity_jitter_mbps*randn());
    availableMbps = max(0, capacityMbps(k) - p.control_overhead_mbps);
    buffer = buffer + (payloadMbps(k) - availableMbps) * dt;
    if buffer > capacityMb
        dropFlag(k) = 1;
        buffer = capacityMb;
    end
    if buffer < 0
        buffer = 0;
    end
    bufferMb(k) = buffer / 8.0;
    latencyMs(k) = 1000.0 * buffer / max(availableMbps, 1e-6);
end

series = table(t, payloadMbps, capacityMbps, bufferMb, latencyMs, dropFlag, ...
    'VariableNames', {'time_s','video_payload_mbps','rf_capacity_mbps','buffer_mb','latency_ms','drop_flag'});

summary = struct();
summary.duration_s = p.duration_s;
summary.frame_rate_fps = p.frame_rate_fps;
summary.resolution = sprintf('%dx%d', p.width_px, p.height_px);
summary.raw_video_mbps = rawMbps;
summary.mean_payload_mbps = mean(payloadMbps);
summary.mean_payload_MBps = mean(payloadMbps) / 8.0;
summary.mean_rf_capacity_mbps = mean(capacityMbps);
summary.max_buffer_mb = max(bufferMb);
summary.mean_latency_ms = mean(latencyMs);
summary.max_latency_ms = max(latencyMs);
summary.dropped_frames = sum(dropFlag);
summary.drop_ratio_percent = sum(dropFlag) / n * 100.0;

video = struct('series', series, 'summary', summary);
fprintf('Video: raw=%.2fMbps, payload=%.2fMbps, capacity=%.2fMbps, max buffer=%.2fMB, drops=%d\n', ...
    rawMbps, summary.mean_payload_mbps, summary.mean_rf_capacity_mbps, summary.max_buffer_mb, summary.dropped_frames);
end

function rf = simulateRfLink(p)
freqs = p.frequencies_mhz(:);
n = numel(freqs);
distance = repmat(p.distance_km, n, 1);
fsplDb = 32.44 + 20*log10(freqs) + 20*log10(distance);

controlRxDbm = p.tx_power_control_dbm + p.tx_antenna_gain_dbi + p.rx_antenna_gain_dbi ...
    - p.total_cable_loss_db - fsplDb;
videoRxDbm = p.tx_power_video_dbm + p.tx_antenna_gain_dbi + p.rx_antenna_gain_dbi ...
    - p.total_cable_loss_db - fsplDb;

controlNoiseDbm = -174 + 10*log10(p.control_bandwidth_hz) + p.noise_figure_db;
videoNoiseDbm = -174 + 10*log10(p.video_bandwidth_hz) + p.noise_figure_db;

controlSnrDb = controlRxDbm - controlNoiseDbm;
videoSnrDb = videoRxDbm - videoNoiseDbm;
controlEbN0Db = controlSnrDb + 10*log10(p.control_bandwidth_hz / p.control_bitrate_bps);
videoEbN0Db = videoSnrDb + 10*log10(p.video_bandwidth_hz / p.video_bitrate_bps);
controlBerTheory = 0.5 * erfc(sqrt(10.^(controlEbN0Db/10)));
videoBerTheory = 0.5 * erfc(sqrt(10.^(videoEbN0Db/10)));

budget = table(freqs, distance, fsplDb, controlRxDbm, videoRxDbm, ...
    repmat(controlNoiseDbm, n, 1), repmat(videoNoiseDbm, n, 1), ...
    controlSnrDb, videoSnrDb, controlEbN0Db, videoEbN0Db, ...
    controlBerTheory, videoBerTheory, ...
    'VariableNames', {'frequency_mhz','distance_km','fspl_db','control_rx_dbm','video_rx_dbm', ...
    'control_noise_dbm','video_noise_dbm','control_snr_db','video_snr_db', ...
    'control_ebn0_db','video_ebn0_db','control_ber_theory','video_ber_theory'});

ebn0 = p.ber_ebn0_db(:);
bits = randi([0 1], p.ber_bits, 1);
berSim = zeros(numel(ebn0), 1);
berTheory = zeros(numel(ebn0), 1);
symbols = 2*bits - 1;
for k = 1:numel(ebn0)
    noiseSigma = sqrt(1 / (2*10^(ebn0(k)/10)));
    rx = symbols + noiseSigma * randn(size(symbols));
    detected = rx >= 0;
    berSim(k) = mean(detected ~= bits);
    berTheory(k) = 0.5 * erfc(sqrt(10^(ebn0(k)/10)));
end
berCurve = table(ebn0, berSim, berTheory, ...
    'VariableNames', {'ebn0_db','ber_simulated','ber_theory'});

summary = struct();
summary.distance_km = p.distance_km;
summary.frequencies_mhz = p.frequencies_mhz;
summary.control_tx_power_dbm = p.tx_power_control_dbm;
summary.video_tx_power_dbm = p.tx_power_video_dbm;
summary.control_bandwidth_hz = p.control_bandwidth_hz;
summary.video_bandwidth_hz = p.video_bandwidth_hz;
summary.min_control_snr_db = min(controlSnrDb);
summary.min_video_snr_db = min(videoSnrDb);
summary.min_control_rx_dbm = min(controlRxDbm);
summary.min_video_rx_dbm = min(videoRxDbm);
summary.video_channel_bandwidth_mhz = p.video_bandwidth_hz / 1e6;
summary.simulated_bits_per_ber_point = p.ber_bits;
summary.ber_at_10db_simulated = berSim(ebn0 == 10);

rf = struct('budget', budget, 'berCurve', berCurve, 'summary', summary);
fprintf('RF: min control SNR=%.2fdB, min video SNR=%.2fdB, BER@10dB=%.6g\n', ...
    summary.min_control_snr_db, summary.min_video_snr_db, summary.ber_at_10db_simulated);
end

function plotMotorResults(series, summary, figuresDir)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 780]);
subplot(3,1,1);
plot(series.time_s, series.target_speed_rpm, 'k--', 'LineWidth', 1.2); hold on;
plot(series.time_s, series.speed_rpm, 'b', 'LineWidth', 1.4);
grid on; ylabel('Speed (rpm)'); legend('Target','Actual', 'Location', 'best');
title(sprintf('Motor speed response, rise90 %.3fs, final %.1frpm', summary.rise_time_90_s, summary.final_speed_rpm));
subplot(3,1,2);
plot(series.time_s, series.current_a, 'r', 'LineWidth', 1.2);
grid on; ylabel('Current (A)');
subplot(3,1,3);
plot(series.time_s, series.pwm_duty, 'Color', [0.1 0.55 0.1], 'LineWidth', 1.2);
grid on; ylabel('PWM duty'); xlabel('Time (s)');
saveFigure(fig, fullfile(figuresDir, 'motor_response.png'));
end

function plotVideoResults(series, summary, figuresDir)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 780]);
subplot(3,1,1);
plot(series.time_s, series.video_payload_mbps, 'b', 'LineWidth', 1.2); hold on;
plot(series.time_s, series.rf_capacity_mbps, 'r', 'LineWidth', 1.1);
grid on; ylabel('Mbps'); legend('Video payload','RF capacity', 'Location', 'best');
title(sprintf('Video link load, payload %.2f MB/s, raw %.2f Mbps', summary.mean_payload_MBps, summary.raw_video_mbps));
subplot(3,1,2);
plot(series.time_s, series.buffer_mb, 'Color', [0.2 0.45 0.2], 'LineWidth', 1.2);
grid on; ylabel('Buffer (MB)');
subplot(3,1,3);
plot(series.time_s, series.latency_ms, 'Color', [0.55 0.2 0.55], 'LineWidth', 1.2);
grid on; ylabel('Latency (ms)'); xlabel('Time (s)');
saveFigure(fig, fullfile(figuresDir, 'video_buffer.png'));
end

function plotRfResults(budget, berCurve, summary, figuresDir)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 780]);
subplot(2,1,1);
plot(budget.frequency_mhz, budget.control_snr_db, '-ob', 'LineWidth', 1.2); hold on;
plot(budget.frequency_mhz, budget.video_snr_db, '-sr', 'LineWidth', 1.2);
grid on; xlabel('Frequency (MHz)'); ylabel('SNR (dB)');
legend('Control channel','Video channel', 'Location', 'best');
title(sprintf('10 km VHF link budget, min video SNR %.2f dB', summary.min_video_snr_db));
subplot(2,1,2);
semilogy(berCurve.ebn0_db, berCurve.ber_simulated, 'ob-', 'LineWidth', 1.2); hold on;
semilogy(berCurve.ebn0_db, berCurve.ber_theory, 'k--', 'LineWidth', 1.2);
grid on; xlabel('Eb/N0 (dB)'); ylabel('BER');
legend('Simulated BPSK','Theory', 'Location', 'southwest');
saveFigure(fig, fullfile(figuresDir, 'rf_link_ber.png'));
end

function drawSystemDiagrams(figuresDir)
drawBlocks(fullfile(figuresDir, 'system_architecture.png'), ...
    '机器人端远程无线控制系统总体结构', ...
    {'摄像头与视频采集', 'TMS320F28379D DSP', '电机驱动器', '射频集成模块', 'VHF天线'}, ...
    [0.07 0.55 0.22 0.20; 0.38 0.55 0.22 0.20; 0.69 0.55 0.22 0.20; 0.38 0.18 0.22 0.20; 0.69 0.18 0.22 0.20], ...
    [1 2; 2 3; 2 4; 4 5]);

drawBlocks(fullfile(figuresDir, 'motor_control_circuit.png'), ...
    '驱动器控制模块原理图', ...
    {'ePWM/HRPWM', '隔离驱动', 'MOSFET桥', '电机', 'ADC采样', 'QEP编码器'}, ...
    [0.05 0.58 0.20 0.18; 0.31 0.58 0.18 0.18; 0.56 0.58 0.18 0.18; 0.80 0.58 0.15 0.18; 0.56 0.22 0.18 0.18; 0.80 0.22 0.15 0.18], ...
    [1 2; 2 3; 3 4; 4 5; 4 6; 5 1; 6 1]);

drawBlocks(fullfile(figuresDir, 'video_capture_circuit.png'), ...
    '视频捕获模块原理图', ...
    {'CMOS摄像头', 'MIPI/并口接收', '帧缓存SDRAM', 'H.264编码器', 'DSP控制接口', '射频发送缓存'}, ...
    [0.05 0.55 0.19 0.18; 0.30 0.55 0.19 0.18; 0.55 0.55 0.19 0.18; 0.78 0.55 0.17 0.18; 0.30 0.20 0.19 0.18; 0.78 0.20 0.17 0.18], ...
    [1 2; 2 3; 3 4; 2 5; 4 6; 5 6]);

drawBlocks(fullfile(figuresDir, 'rf_integrated_circuit.png'), ...
    '射频集成模块原理图', ...
    {'DAC/ADC', '调制解调', '频率合成', '滤波器组', 'LNA/PA', '天线匹配'}, ...
    [0.05 0.58 0.18 0.18; 0.29 0.58 0.18 0.18; 0.53 0.58 0.18 0.18; 0.29 0.22 0.18 0.18; 0.53 0.22 0.18 0.18; 0.77 0.40 0.18 0.18], ...
    [1 2; 2 3; 2 4; 3 5; 4 5; 5 6]);

drawBlocks(fullfile(figuresDir, 'software_flow.png'), ...
    'MATLAB/Simulink软件流程', ...
    {'参数加载', '电机控制仿真', '视频链路仿真', '射频链路仿真', '结果校验', '报告生成'}, ...
    [0.05 0.58 0.17 0.18; 0.29 0.58 0.17 0.18; 0.53 0.58 0.17 0.18; 0.77 0.58 0.17 0.18; 0.29 0.22 0.17 0.18; 0.53 0.22 0.17 0.18], ...
    [1 2; 2 3; 3 4; 4 5; 5 6]);
end

function drawBlocks(filePath, titleText, labels, positions, edges)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1150 650]);
axis([0 1 0 1]); axis off; hold on;
title(titleText, 'FontName', 'SimSun', 'FontSize', 16, 'FontWeight', 'bold');
colors = [0.86 0.93 0.98; 0.92 0.96 0.88; 0.98 0.92 0.86; 0.94 0.90 0.98; 0.98 0.96 0.84; 0.88 0.95 0.94];
centers = zeros(numel(labels), 2);
for i = 1:numel(labels)
    pos = positions(i, :);
    rectangle('Position', pos, 'Curvature', 0.04, 'FaceColor', colors(mod(i-1, size(colors,1))+1,:), ...
        'EdgeColor', [0.25 0.25 0.25], 'LineWidth', 1.2);
    centers(i, :) = [pos(1)+pos(3)/2, pos(2)+pos(4)/2];
    text(centers(i,1), centers(i,2), labels{i}, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'FontName', 'SimSun', 'FontSize', 12);
end
for k = 1:size(edges, 1)
    fromIdx = edges(k,1);
    toIdx = edges(k,2);
    a = edgePoint(positions(fromIdx, :), centers(fromIdx, :), centers(toIdx, :), 0.012);
    b = edgePoint(positions(toIdx, :), centers(toIdx, :), centers(fromIdx, :), 0.012);
    quiver(a(1), a(2), b(1)-a(1), b(2)-a(2), 0, 'Color', [0.25 0.25 0.25], ...
        'LineWidth', 1.2, 'MaxHeadSize', 0.18);
end
saveFigure(fig, filePath);
end

function p = edgePoint(rect, center, toward, pad)
dx = toward(1) - center(1);
dy = toward(2) - center(2);
if abs(dx) < 1e-9 && abs(dy) < 1e-9
    p = center;
    return;
end
halfW = rect(3) / 2;
halfH = rect(4) / 2;
scale = min(halfW / max(abs(dx), 1e-9), halfH / max(abs(dy), 1e-9));
p = center + [dx dy] * scale;
p = p + pad * [dx dy] / sqrt(dx*dx + dy*dy);
end

function status = createSimulinkModel(modelsDir)
status = struct();
status.created = false;
status.path = normalizePath(fullfile(modelsDir, 'robot_wireless_control_system.slx'));
status.note = '';
status.screenshots = struct();
try
    modelName = 'robot_wireless_control_system';
    modelPath = fullfile(modelsDir, [modelName '.slx']);
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    if exist(modelPath, 'file')
        delete(modelPath);
    end
    oldModel = fullfile(modelsDir, 'robot_motor_closed_loop.slx');
    if exist(oldModel, 'file')
        delete(oldModel);
    end

    new_system(modelName);
    open_system(modelName);
    set_param(modelName, 'StopTime', '2.5', 'Solver', 'ode4', 'FixedStep', '5e-4');

    addTopSubsystem(modelName, 'Command Scheduler', [50 80 210 155], ...
        {'Start/reverse command', 'Speed profile'});
    addTopSubsystem(modelName, 'DSP Control Algorithm', [280 65 470 170], ...
        {'PID + anti-windup', 'Current limit', 'Fault logic'});
    addTopSubsystem(modelName, 'PWM and Isolated Gate Driver', [540 80 760 155], ...
        {'ePWM compare', 'Dead-time', 'Gate isolation'});
    addTopSubsystem(modelName, 'Power Stage and DC Motor', [830 65 1050 170], ...
        {'24 V bridge', 'Electrical model', 'Mechanical load'});
    addTopSubsystem(modelName, 'Sensor Acquisition', [600 245 810 340], ...
        {'ADC current/voltage', 'QEP speed', 'Quantization'});
    addTopSubsystem(modelName, 'Video Capture Pipeline', [50 430 265 535], ...
        {'CMOS camera', 'Frame buffer', 'H.264 payload'});
    addTopSubsystem(modelName, 'RF Link and Packet Channel', [350 430 590 535], ...
        {'VHF path loss', 'BPSK control', 'Video capacity'});
    addTopSubsystem(modelName, 'Performance Monitors', [700 430 950 535], ...
        {'Speed metrics', 'Buffer latency', 'BER/SNR'});

    populateCommandSubsystem([modelName '/Command Scheduler']);
    populateDspControlSubsystem([modelName '/DSP Control Algorithm']);
    populatePwmSubsystem([modelName '/PWM and Isolated Gate Driver']);
    populateMotorPlantSubsystem([modelName '/Power Stage and DC Motor']);
    populateSensorSubsystem([modelName '/Sensor Acquisition']);
    populateVideoSubsystem([modelName '/Video Capture Pipeline']);
    populateRfSubsystem([modelName '/RF Link and Packet Channel']);
    populateMonitorSubsystem([modelName '/Performance Monitors']);

    add_line(modelName, 'Command Scheduler/1', 'DSP Control Algorithm/1', 'autorouting', 'on');
    add_line(modelName, 'DSP Control Algorithm/1', 'PWM and Isolated Gate Driver/1', 'autorouting', 'on');
    add_line(modelName, 'PWM and Isolated Gate Driver/1', 'Power Stage and DC Motor/1', 'autorouting', 'on');
    add_line(modelName, 'Power Stage and DC Motor/1', 'Sensor Acquisition/1', 'autorouting', 'on');
    add_line(modelName, 'Sensor Acquisition/1', 'DSP Control Algorithm/2', 'autorouting', 'on');
    add_line(modelName, 'Sensor Acquisition/1', 'Performance Monitors/1', 'autorouting', 'on');
    add_line(modelName, 'Video Capture Pipeline/1', 'RF Link and Packet Channel/1', 'autorouting', 'on');
    add_line(modelName, 'RF Link and Packet Channel/1', 'Performance Monitors/2', 'autorouting', 'on');

    set_param(modelName, 'ZoomFactor', 'FitSystem');
    set_param(modelName, 'SimulationCommand', 'update');

    figuresDir = fullfile(fileparts(modelsDir), 'output', 'figures');
    ensureDir(figuresDir);
    topShot = fullfile(figuresDir, 'simulink_model_top.png');
    controlShot = fullfile(figuresDir, 'simulink_model_control_subsystem.png');
    linkShot = fullfile(figuresDir, 'simulink_model_video_rf_subsystems.png');
    print(['-s' modelName], topShot, '-dpng', '-r180');
    open_system([modelName '/DSP Control Algorithm']);
    set_param([modelName '/DSP Control Algorithm'], 'ZoomFactor', 'FitSystem');
    print(['-s' modelName '/DSP Control Algorithm'], controlShot, '-dpng', '-r180');
    open_system([modelName '/RF Link and Packet Channel']);
    set_param([modelName '/RF Link and Packet Channel'], 'ZoomFactor', 'FitSystem');
    print(['-s' modelName '/RF Link and Packet Channel'], linkShot, '-dpng', '-r180');

    save_system(modelName, modelPath);
    close_system(modelName, 0);
    status.created = true;
    status.note = 'Hierarchical Simulink model generated with control, power-stage, sensing, video, RF, and monitoring subsystems.';
    status.screenshots.top_level = normalizePath(topShot);
    status.screenshots.control_subsystem = normalizePath(controlShot);
    status.screenshots.video_rf_subsystem = normalizePath(linkShot);
    fprintf('Simulink model generated: %s\n', modelPath);
catch err
    status.note = ['Simulink model generation failed: ' err.message];
    fprintf('Simulink model failed: %s\n', status.note);
end
end

function addTopSubsystem(modelName, name, pos, notes)
path = [modelName '/' name];
add_block('built-in/Subsystem', path, 'Position', pos);
set_param(path, 'BackgroundColor', 'lightBlue');
try
    set_param(path, 'ContentPreviewEnabled', 'off');
catch
end
end

function populateCommandSubsystem(path)
emptySubsystem(path);
add_block('simulink/Sources/Step', [path '/Forward command'], 'Time', '0.02', ...
    'Before', '0', 'After', '600', 'Position', [40 45 80 75]);
add_block('simulink/Sources/Step', [path '/Reverse command'], 'Time', '1.20', ...
    'Before', '0', 'After', '-1200', 'Position', [40 110 80 140]);
add_block('simulink/Math Operations/Sum', [path '/Signed speed reference'], ...
    'Inputs', '++', 'Position', [135 78 165 112]);
addOutport(path, 'SpeedRef_rpm', [235 88 265 108]);
add_line(path, 'Forward command/1', 'Signed speed reference/1');
add_line(path, 'Reverse command/1', 'Signed speed reference/2');
add_line(path, 'Signed speed reference/1', 'SpeedRef_rpm/1');
end

function populateDspControlSubsystem(path)
emptySubsystem(path);
addInport(path, 'SpeedRef_rpm', [25 55 55 75]);
addInport(path, 'SpeedFeedback_rpm', [25 125 55 145]);
add_block('simulink/Math Operations/Sum', [path '/Speed error'], 'Inputs', '+-', ...
    'Position', [95 75 125 110]);
add_block('simulink/Math Operations/Gain', [path '/Kp'], 'Gain', '0.12', ...
    'Position', [165 40 220 70]);
add_block('simulink/Discrete/Discrete-Time Integrator', [path '/Ki integrator'], ...
    'gainval', '3.2', 'SampleTime', '5e-4', 'Position', [160 92 225 128]);
add_block('simulink/Math Operations/Gain', [path '/Kd filtered'], 'Gain', '0.001', ...
    'Position', [165 150 225 180]);
add_block('simulink/Math Operations/Sum', [path '/Voltage command'], 'Inputs', '+++', ...
    'Position', [275 83 305 127]);
add_block('simulink/Discontinuities/Saturation', [path '/DC bus clamp'], ...
    'UpperLimit', '24', 'LowerLimit', '-24', 'Position', [345 85 415 125]);
add_block('simulink/Discontinuities/Saturation', [path '/Current protection derate'], ...
    'UpperLimit', '22', 'LowerLimit', '-22', 'Position', [455 85 535 125]);
addOutport(path, 'VoltageCmd_V', [590 96 620 116]);
add_line(path, 'SpeedRef_rpm/1', 'Speed error/1');
add_line(path, 'SpeedFeedback_rpm/1', 'Speed error/2');
add_line(path, 'Speed error/1', 'Kp/1');
add_line(path, 'Speed error/1', 'Ki integrator/1');
add_line(path, 'Speed error/1', 'Kd filtered/1');
add_line(path, 'Kp/1', 'Voltage command/1');
add_line(path, 'Ki integrator/1', 'Voltage command/2');
add_line(path, 'Kd filtered/1', 'Voltage command/3');
add_line(path, 'Voltage command/1', 'DC bus clamp/1');
add_line(path, 'DC bus clamp/1', 'Current protection derate/1');
add_line(path, 'Current protection derate/1', 'VoltageCmd_V/1');
end

function populatePwmSubsystem(path)
emptySubsystem(path);
addInport(path, 'VoltageCmd_V', [35 80 65 100]);
add_block('simulink/Math Operations/Gain', [path '/Normalize by Vdc'], 'Gain', '1/24', ...
    'Position', [115 75 185 105]);
add_block('simulink/Discontinuities/Saturation', [path '/Duty clamp 0..1'], ...
    'UpperLimit', '1', 'LowerLimit', '-1', 'Position', [235 75 315 105]);
add_block('simulink/Discontinuities/Dead Zone', [path '/Dead-time equivalent'], ...
    'LowerValue', '-0.02', 'UpperValue', '0.02', 'Position', [365 75 450 105]);
addOutport(path, 'BridgeDuty', [515 82 545 102]);
add_line(path, 'VoltageCmd_V/1', 'Normalize by Vdc/1');
add_line(path, 'Normalize by Vdc/1', 'Duty clamp 0..1/1');
add_line(path, 'Duty clamp 0..1/1', 'Dead-time equivalent/1');
add_line(path, 'Dead-time equivalent/1', 'BridgeDuty/1');
end

function populateMotorPlantSubsystem(path)
emptySubsystem(path);
addInport(path, 'BridgeDuty', [35 90 65 110]);
add_block('simulink/Math Operations/Gain', [path '/DC bus voltage'], 'Gain', '24', ...
    'Position', [105 85 165 115]);
add_block('simulink/Continuous/Transfer Fcn', [path '/Armature electrical dynamics'], ...
    'Numerator', '[1]', 'Denominator', '[0.0035 0.8]', 'Position', [210 80 335 120]);
add_block('simulink/Math Operations/Gain', [path '/Torque constant'], 'Gain', '0.25', ...
    'Position', [380 85 445 115]);
add_block('simulink/Continuous/Transfer Fcn', [path '/Mechanical dynamics'], ...
    'Numerator', '[1]', 'Denominator', '[0.008 0.02]', 'Position', [490 80 615 120]);
add_block('simulink/Math Operations/Gain', [path '/radps to rpm'], 'Gain', '60/(2*pi)', ...
    'Position', [650 85 735 115]);
addOutport(path, 'MotorSpeed_rpm', [790 92 820 112]);
add_line(path, 'BridgeDuty/1', 'DC bus voltage/1');
add_line(path, 'DC bus voltage/1', 'Armature electrical dynamics/1');
add_line(path, 'Armature electrical dynamics/1', 'Torque constant/1');
add_line(path, 'Torque constant/1', 'Mechanical dynamics/1');
add_line(path, 'Mechanical dynamics/1', 'radps to rpm/1');
add_line(path, 'radps to rpm/1', 'MotorSpeed_rpm/1');
end

function populateSensorSubsystem(path)
emptySubsystem(path);
addInport(path, 'MotorSpeed_rpm', [35 70 65 90]);
add_block('simulink/Discontinuities/Quantizer', [path '/QEP quantization'], ...
    'QuantizationInterval', '0.5', 'Position', [125 65 205 95]);
add_block('simulink/Discrete/Unit Delay', [path '/Sample delay'], ...
    'SampleTime', '5e-4', 'Position', [255 65 325 95]);
addOutport(path, 'MeasuredSpeed_rpm', [395 72 425 92]);
add_line(path, 'MotorSpeed_rpm/1', 'QEP quantization/1');
add_line(path, 'QEP quantization/1', 'Sample delay/1');
add_line(path, 'Sample delay/1', 'MeasuredSpeed_rpm/1');
end

function populateVideoSubsystem(path)
emptySubsystem(path);
add_block('simulink/Sources/Constant', [path '/720p25 raw source'], 'Value', '552.96', ...
    'Position', [40 135 110 165]);
add_block('simulink/Math Operations/Gain', [path '/H264 compression ratio'], 'Gain', '36/552.96', ...
    'Position', [165 130 265 170]);
add_block('simulink/Discrete/Discrete-Time Integrator', [path '/Frame buffer occupancy'], ...
    'gainval', '1', 'SampleTime', '0.04', 'Position', [320 130 430 170]);
addOutport(path, 'VideoPayload_Mbps', [495 140 525 160]);
add_line(path, '720p25 raw source/1', 'H264 compression ratio/1');
add_line(path, 'H264 compression ratio/1', 'Frame buffer occupancy/1');
add_line(path, 'Frame buffer occupancy/1', 'VideoPayload_Mbps/1');
end

function populateRfSubsystem(path)
emptySubsystem(path);
addInport(path, 'VideoPayload_Mbps', [35 92 65 112]);
add_block('simulink/Sources/Constant', [path '/VHF path-loss margin'], 'Value', '44.76', ...
    'Position', [35 155 130 185]);
add_block('simulink/Math Operations/Sum', [path '/Capacity residual'], 'Inputs', '+-', ...
    'Position', [190 103 220 137]);
add_block('simulink/Sources/Constant', [path '/Nominal RF capacity'], 'Value', '42', ...
    'Position', [85 35 150 65]);
add_block('simulink/Discontinuities/Saturation', [path '/Packet reliability clamp'], ...
    'UpperLimit', '1', 'LowerLimit', '0', 'Position', [280 103 370 137]);
addOutport(path, 'LinkHealth', [435 110 465 130]);
add_line(path, 'Nominal RF capacity/1', 'Capacity residual/1');
add_line(path, 'VideoPayload_Mbps/1', 'Capacity residual/2');
add_line(path, 'Capacity residual/1', 'Packet reliability clamp/1');
add_line(path, 'Packet reliability clamp/1', 'LinkHealth/1');
end

function populateMonitorSubsystem(path)
emptySubsystem(path);
addInport(path, 'MotorTelemetry', [35 55 65 75]);
addInport(path, 'LinkHealth', [35 130 65 150]);
add_block('simulink/Signal Routing/Mux', [path '/Metric vector'], 'Inputs', '2', ...
    'Position', [135 82 165 128]);
add_block('simulink/Sinks/To Workspace', [path '/metrics_to_workspace'], ...
    'VariableName', 'sim_metrics', 'Position', [230 92 335 122]);
add_line(path, 'MotorTelemetry/1', 'Metric vector/1');
add_line(path, 'LinkHealth/1', 'Metric vector/2');
add_line(path, 'Metric vector/1', 'metrics_to_workspace/1');
end

function emptySubsystem(path)
lines = get_param(path, 'Lines');
for i = 1:numel(lines)
    try
        delete_line(lines(i).Handle);
    catch
    end
end
blocks = find_system(path, 'SearchDepth', 1, 'Type', 'Block');
for i = 1:numel(blocks)
    if ~strcmp(blocks{i}, path)
        try
            delete_block(blocks{i});
        catch
        end
    end
end
end

function addInport(path, name, pos)
add_block('simulink/Sources/In1', [path '/' name], 'Position', pos);
end

function addOutport(path, name, pos)
add_block('simulink/Sinks/Out1', [path '/' name], 'Position', pos);
end

function txt = captureToolboxes()
v = ver;
lines = cell(numel(v)+2, 1);
lines{1} = sprintf('MATLAB version: %s', version);
lines{2} = sprintf('Generated: %s', datestr(now, 31));
for i = 1:numel(v)
    lines{i+2} = sprintf('%s | %s | %s', v(i).Name, v(i).Version, v(i).Release);
end
txt = strjoin(lines, newline);
end

function saveFigure(fig, filePath)
set(fig, 'PaperPositionMode', 'auto');
print(fig, filePath, '-dpng', '-r180');
close(fig);
fprintf('Figure saved: %s\n', filePath);
end

function ensureDir(pathValue)
if ~exist(pathValue, 'dir')
    mkdir(pathValue);
end
end

function writeJson(filePath, data)
fid = fopen(filePath, 'w', 'n', 'UTF-8');
assert(fid > 0, 'Cannot open file for writing: %s', filePath);
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(data));
end

function writeText(filePath, txt)
fid = fopen(filePath, 'w', 'n', 'UTF-8');
assert(fid > 0, 'Cannot open file for writing: %s', filePath);
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, '%s', txt);
end

function p = normalizePath(p)
p = strrep(p, '\', '/');
end

function s = signOrOne(x)
if x >= 0
    s = 1;
else
    s = -1;
end
end
