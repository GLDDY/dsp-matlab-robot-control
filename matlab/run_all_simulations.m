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

agenticStatus = initializeAgenticToolkits(projectRoot, logsDir);
writeJson(fullfile(logsDir, 'agentic_toolkit_status.json'), agenticStatus);

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
simulinkStatus = createSimulinkModel(modelsDir, resultsDir, params, agenticStatus);
writeJson(fullfile(resultsDir, 'simulink_model_status.json'), simulinkStatus);

summary = struct();
summary.generated_at = datestr(now, 31);
summary.matlab_version = version;
summary.motor = motor.summary;
summary.video = video.summary;
summary.rf = rf.summary;
summary.simulink = simulinkStatus;
summary.agentic_toolkits = agenticStatus;
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

function status = initializeAgenticToolkits(projectRoot, logsDir)
status = struct();
status.requested = true;
status.checked_at = datestr(now, 31);
status.matlab_version = version;
simulinkInfo = ver('simulink');
if isempty(simulinkInfo)
    status.simulink_version = '';
else
    status.simulink_version = sprintf('%s %s', simulinkInfo.Version, simulinkInfo.Release);
end
status.project_root = normalizePath(projectRoot);
status.install_root = normalizePath(fullfile(char(java.lang.System.getProperty('user.home')), '.matlab', 'agentic-toolkits'));
status.matlab_toolkit_path = normalizePath(fullfile(status.install_root, 'matlab'));
status.simulink_toolkit_path = normalizePath(fullfile(status.install_root, 'simulink'));
status.mcp_server_path = normalizePath(fullfile(status.install_root, 'bin', 'matlab-mcp-server.exe'));
status.satk_initialize = '';
status.share_matlab_session = '';
status.initialized = false;
status.setup_method = 'Official MathWorks toolkit paths; setupAgenticToolkit installer plus manual MCP Server asset fallback when the renamed release asset is required.';
status.skills_applied = {'building-simulink-models', 'simulating-simulink-models'};
status.notes = {};
status.error = '';

try
    if exist(status.matlab_toolkit_path, 'dir')
        addpath(status.matlab_toolkit_path);
    else
        status.notes{end+1} = 'MATLAB Agentic Toolkit folder is not present.';
    end
    if exist(status.simulink_toolkit_path, 'dir')
        addpath(status.simulink_toolkit_path);
    else
        status.notes{end+1} = 'Simulink Agentic Toolkit folder is not present.';
    end

    status.satk_initialize = which('satk_initialize');
    status.share_matlab_session = which('shareMATLABSession');
    status.mcp_server_exists = exist(status.mcp_server_path, 'file') == 2;

    if isempty(status.satk_initialize)
        status.notes{end+1} = 'satk_initialize was not found on MATLAB path.';
    else
        satk_initialize;
        status.initialized = true;
        status.notes{end+1} = 'satk_initialize completed successfully in MATLAB R2025a.';
    end
catch err
    status.error = err.message;
    status.notes{end+1} = ['Agentic toolkit initialization failed: ' err.message];
end

status.log_path = normalizePath(fullfile(logsDir, 'agentic_toolkit_status.json'));
if isempty(status.notes)
    status.notes = {'No warnings.'};
end
fprintf('Agentic toolkit initialized: %d\n', status.initialized);
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

function status = createSimulinkModel(modelsDir, resultsDir, params, agenticStatus)
status = struct();
status.created = false;
status.path = normalizePath(fullfile(modelsDir, 'robot_wireless_control_system.slx'));
status.note = '';
status.screenshots = struct();
status.agentic_toolkit_initialized = agenticStatus.initialized;
status.applied_skill_guidance = {'building-simulink-models', 'simulating-simulink-models'};
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
    set_param(modelName, ...
        'StopTime', num2str(params.motor.stop_time_s), ...
        'SolverType', 'Fixed-step', ...
        'Solver', 'ode4', ...
        'FixedStep', num2str(params.motor.sample_time_s), ...
        'SignalLogging', 'on', ...
        'ReturnWorkspaceOutputs', 'on');
    configureModelWorkspace(modelName, params);

    addTopSubsystem(modelName, 'Command_Scheduler', [45 72 230 170], ...
        {'Speed command profile', 'Rate limited setpoint'});
    addTopSubsystem(modelName, 'DSP_Control_Algorithm', [295 55 515 185], ...
        {'Discrete PID', 'Anti-windup clamp', 'Current fault derating'});
    addTopSubsystem(modelName, 'PWM_Gate_Driver_HBridge', [590 75 815 170], ...
        {'Duty normalization', 'Dead-time model', 'Isolated driver'});
    addTopSubsystem(modelName, 'DC_Motor_Electromechanical_Plant', [890 55 1165 185], ...
        {'Armature dynamics', 'Torque and load', 'Speed/current telemetry'});
    addTopSubsystem(modelName, 'ADC_QEP_Sensor_Acquisition', [625 255 850 370], ...
        {'QEP quantization', 'ADC current limit', 'Sample delay'});
    addTopSubsystem(modelName, 'Video_Capture_Codec_Buffer', [45 455 300 585], ...
        {'CMOS stream', 'H.264 payload', 'Frame buffer'});
    addTopSubsystem(modelName, 'VHF_RF_Transceiver_Channel', [390 455 640 585], ...
        {'Capacity residual', 'SNR margin', 'Packet health'});
    addTopSubsystem(modelName, 'Supervisor_Performance_Monitors', [735 430 1040 610], ...
        {'Speed/fault metrics', 'Video buffer', 'RF health logging'});

    populateCommandSubsystem([modelName '/Command_Scheduler']);
    populateDspControlSubsystem([modelName '/DSP_Control_Algorithm']);
    populatePwmSubsystem([modelName '/PWM_Gate_Driver_HBridge']);
    populateMotorPlantSubsystem([modelName '/DC_Motor_Electromechanical_Plant']);
    populateSensorSubsystem([modelName '/ADC_QEP_Sensor_Acquisition']);
    populateVideoSubsystem([modelName '/Video_Capture_Codec_Buffer']);
    populateRfSubsystem([modelName '/VHF_RF_Transceiver_Channel']);
    populateMonitorSubsystem([modelName '/Supervisor_Performance_Monitors']);

    add_line(modelName, 'Command_Scheduler/1', 'DSP_Control_Algorithm/1', 'autorouting', 'on');
    add_line(modelName, 'DSP_Control_Algorithm/1', 'PWM_Gate_Driver_HBridge/1', 'autorouting', 'on');
    add_line(modelName, 'PWM_Gate_Driver_HBridge/1', 'DC_Motor_Electromechanical_Plant/1', 'autorouting', 'on');
    add_line(modelName, 'DC_Motor_Electromechanical_Plant/1', 'ADC_QEP_Sensor_Acquisition/1', 'autorouting', 'on');
    add_line(modelName, 'ADC_QEP_Sensor_Acquisition/1', 'DSP_Control_Algorithm/2', 'autorouting', 'on');
    add_line(modelName, 'ADC_QEP_Sensor_Acquisition/2', 'DSP_Control_Algorithm/3', 'autorouting', 'on');
    add_line(modelName, 'ADC_QEP_Sensor_Acquisition/1', 'Supervisor_Performance_Monitors/1', 'autorouting', 'on');
    add_line(modelName, 'ADC_QEP_Sensor_Acquisition/2', 'Supervisor_Performance_Monitors/2', 'autorouting', 'on');
    add_line(modelName, 'Video_Capture_Codec_Buffer/1', 'VHF_RF_Transceiver_Channel/1', 'autorouting', 'on');
    add_line(modelName, 'Video_Capture_Codec_Buffer/2', 'VHF_RF_Transceiver_Channel/2', 'autorouting', 'on');
    add_line(modelName, 'Video_Capture_Codec_Buffer/1', 'Supervisor_Performance_Monitors/3', 'autorouting', 'on');
    add_line(modelName, 'Video_Capture_Codec_Buffer/2', 'Supervisor_Performance_Monitors/4', 'autorouting', 'on');
    add_line(modelName, 'VHF_RF_Transceiver_Channel/1', 'Supervisor_Performance_Monitors/5', 'autorouting', 'on');
    add_line(modelName, 'VHF_RF_Transceiver_Channel/2', 'Supervisor_Performance_Monitors/6', 'autorouting', 'on');

    set_param(modelName, 'ZoomFactor', 'FitSystem');
    set_param(modelName, 'SimulationCommand', 'update');
    smoke = runSimulinkSmokeTest(modelName);

    figuresDir = fullfile(fileparts(modelsDir), 'output', 'figures');
    ensureDir(figuresDir);
    topShot = fullfile(figuresDir, 'simulink_model_top.png');
    controlShot = fullfile(figuresDir, 'simulink_model_control_subsystem.png');
    linkShot = fullfile(figuresDir, 'simulink_model_video_rf_subsystems.png');
    print(['-s' modelName], topShot, '-dpng', '-r180');
    open_system([modelName '/DSP_Control_Algorithm']);
    set_param([modelName '/DSP_Control_Algorithm'], 'ZoomFactor', 'FitSystem');
    print(['-s' modelName '/DSP_Control_Algorithm'], controlShot, '-dpng', '-r180');
    open_system([modelName '/VHF_RF_Transceiver_Channel']);
    set_param([modelName '/VHF_RF_Transceiver_Channel'], 'ZoomFactor', 'FitSystem');
    print(['-s' modelName '/VHF_RF_Transceiver_Channel'], linkShot, '-dpng', '-r180');

    save_system(modelName, modelPath);
    architectureReview = summarizeSimulinkArchitecture(modelName, params, smoke, agenticStatus);
    writeJson(fullfile(resultsDir, 'model_architecture_review.json'), architectureReview);
    close_system(modelName, 0);
    status.created = true;
    status.note = 'R2025a hierarchical Simulink model generated with model-workspace parameters, explicit telemetry interfaces, DSP derating logic, video buffer, RF health, and SimulationInput smoke test.';
    status.subsystems = architectureReview.subsystems;
    status.block_count = architectureReview.block_count;
    status.line_count = architectureReview.line_count;
    status.model_workspace_variables = architectureReview.model_workspace_variables;
    status.simulation_smoke_test = smoke;
    status.architecture_review_path = normalizePath(fullfile(resultsDir, 'model_architecture_review.json'));
    status.screenshots.top_level = normalizePath(topShot);
    status.screenshots.control_subsystem = normalizePath(controlShot);
    status.screenshots.video_rf_subsystem = normalizePath(linkShot);
    fprintf('Simulink model generated: %s\n', modelPath);
catch err
    status.note = ['Simulink model generation failed: ' err.message];
    fprintf('Simulink model failed: %s\n', status.note);
end
end

function configureModelWorkspace(modelName, params)
mdlWks = get_param(modelName, 'ModelWorkspace');
assignin(mdlWks, 'Ts_ctrl', params.motor.sample_time_s);
assignin(mdlWks, 'Ts_video', 1 / params.video.frame_rate_fps);
assignin(mdlWks, 'ForwardSpeed_rpm', params.motor.target_speed_rpm);
assignin(mdlWks, 'ReverseDelta_rpm', -2 * params.motor.target_speed_rpm);
assignin(mdlWks, 'ReverseTime_s', params.motor.reverse_time_s);
assignin(mdlWks, 'LoadStepTime_s', params.motor.load_step_time_s);
assignin(mdlWks, 'LoadTorque_Nm', params.motor.load_torque_nm);
assignin(mdlWks, 'Vdc_V', params.motor.dc_bus_v);
assignin(mdlWks, 'Kp_speed', params.motor.pid_kp);
assignin(mdlWks, 'Ki_speed', params.motor.pid_ki);
assignin(mdlWks, 'Kd_over_Ts', params.motor.pid_kd / params.motor.sample_time_s);
assignin(mdlWks, 'ArmatureL_H', params.motor.armature_inductance_h);
assignin(mdlWks, 'ArmatureR_Ohm', params.motor.armature_resistance_ohm);
assignin(mdlWks, 'TorqueConstant_Nm_per_A', params.motor.torque_constant_nm_per_a);
assignin(mdlWks, 'RotorInertia_kgm2', params.motor.rotor_inertia_kgm2);
assignin(mdlWks, 'ViscousFriction_Nm_s', params.motor.viscous_friction_nms);
assignin(mdlWks, 'CurrentLimit_A', params.motor.current_limit_a);
assignin(mdlWks, 'RawVideo_Mbps', params.video.width_px * params.video.height_px * params.video.raw_bits_per_pixel * params.video.frame_rate_fps / 1e6);
assignin(mdlWks, 'VideoPayloadNominal_Mbps', params.video.mean_payload_mbps);
assignin(mdlWks, 'RFVideoCapacity_Mbps', params.video.rf_capacity_mbps);
assignin(mdlWks, 'ControlOverhead_Mbps', params.video.control_overhead_mbps);
assignin(mdlWks, 'InitialBuffer_MB', params.video.initial_buffer_mb);
assignin(mdlWks, 'BufferCapacity_MB', params.video.buffer_capacity_mb);
assignin(mdlWks, 'MinVideoSNR_dB', 44.76);
end

function addTopSubsystem(modelName, name, pos, notes)
path = [modelName '/' name];
add_block('built-in/Subsystem', path, 'Position', pos);
set_param(path, 'BackgroundColor', 'lightBlue');
set_param(path, 'ShowName', 'off');
try
    set_param(path, 'Mask', 'on');
    set_param(path, 'MaskDisplay', ['disp(''' strrep(strrep(name, '_', ' '), '''', '''''') ''')']);
catch
end
try
    set_param(path, 'ContentPreviewEnabled', 'off');
catch
end
end

function populateCommandSubsystem(path)
emptySubsystem(path);
add_block('simulink/Sources/Step', [path '/forward_command'], 'Time', '0.02', ...
    'Before', '0', 'After', 'ForwardSpeed_rpm', 'Position', [35 55 75 85]);
add_block('simulink/Sources/Step', [path '/reverse_delta'], 'Time', 'ReverseTime_s', ...
    'Before', '0', 'After', 'ReverseDelta_rpm', 'Position', [35 125 75 155]);
add_block('simulink/Math Operations/Sum', [path '/signed_speed_reference'], ...
    'Inputs', '++', 'Position', [130 82 160 128]);
add_block('simulink/Discontinuities/Rate Limiter', [path '/command_slew_limit'], ...
    'RisingSlewLimit', '5000', 'FallingSlewLimit', '-5000', 'Position', [210 88 300 122]);
addOutport(path, 'SpeedRef_rpm', [360 98 390 118]);
add_line(path, 'forward_command/1', 'signed_speed_reference/1');
add_line(path, 'reverse_delta/1', 'signed_speed_reference/2');
add_line(path, 'signed_speed_reference/1', 'command_slew_limit/1');
add_line(path, 'command_slew_limit/1', 'SpeedRef_rpm/1');
end

function populateDspControlSubsystem(path)
emptySubsystem(path);
addInport(path, 'SpeedRef_rpm', [25 55 55 75]);
addInport(path, 'SpeedFeedback_rpm', [25 125 55 145]);
addInport(path, 'CurrentFault_0to1', [25 205 55 225]);
add_block('simulink/Math Operations/Sum', [path '/speed_error'], 'Inputs', '+-', ...
    'Position', [95 82 125 118]);
add_block('simulink/Math Operations/Gain', [path '/Kp_speed'], 'Gain', 'Kp_speed', ...
    'Position', [165 35 235 65]);
add_block('simulink/Discrete/Discrete-Time Integrator', [path '/Ki_anti_windup_integrator'], ...
    'gainval', 'Ki_speed', 'SampleTime', 'Ts_ctrl', 'UpperSaturationLimit', 'Vdc_V', ...
    'LowerSaturationLimit', '-Vdc_V', 'Position', [160 88 250 130]);
add_block('simulink/Discrete/Unit Delay', [path '/error_z1'], ...
    'SampleTime', 'Ts_ctrl', 'Position', [160 160 220 190]);
add_block('simulink/Math Operations/Sum', [path '/error_delta'], 'Inputs', '+-', ...
    'Position', [265 158 295 192]);
add_block('simulink/Math Operations/Gain', [path '/Kd_over_Ts'], 'Gain', 'Kd_over_Ts', ...
    'Position', [335 160 410 190]);
add_block('simulink/Math Operations/Sum', [path '/pid_voltage_sum'], 'Inputs', '+++', ...
    'Position', [455 82 485 128]);
add_block('simulink/Discontinuities/Saturation', [path '/dc_bus_voltage_clamp'], ...
    'UpperLimit', 'Vdc_V', 'LowerLimit', '-Vdc_V', 'Position', [530 86 610 124]);
add_block('simulink/Sources/Constant', [path '/healthy_gain'], 'Value', '1', ...
    'Position', [525 195 555 225]);
add_block('simulink/Math Operations/Sum', [path '/fault_derate_gain'], 'Inputs', '+-', ...
    'Position', [610 198 640 228]);
add_block('simulink/Discontinuities/Saturation', [path '/fault_gain_clamp'], ...
    'UpperLimit', '1', 'LowerLimit', '0', 'Position', [680 198 755 228]);
add_block('simulink/Math Operations/Product', [path '/protected_voltage_cmd'], ...
    'Position', [790 105 835 145]);
addOutport(path, 'VoltageCmd_V', [895 116 925 136]);
add_line(path, 'SpeedRef_rpm/1', 'speed_error/1', 'autorouting', 'on');
add_line(path, 'SpeedFeedback_rpm/1', 'speed_error/2', 'autorouting', 'on');
add_line(path, 'speed_error/1', 'Kp_speed/1', 'autorouting', 'on');
add_line(path, 'speed_error/1', 'Ki_anti_windup_integrator/1', 'autorouting', 'on');
add_line(path, 'speed_error/1', 'error_z1/1', 'autorouting', 'on');
add_line(path, 'speed_error/1', 'error_delta/1', 'autorouting', 'on');
add_line(path, 'error_z1/1', 'error_delta/2', 'autorouting', 'on');
add_line(path, 'error_delta/1', 'Kd_over_Ts/1', 'autorouting', 'on');
add_line(path, 'Kp_speed/1', 'pid_voltage_sum/1', 'autorouting', 'on');
add_line(path, 'Ki_anti_windup_integrator/1', 'pid_voltage_sum/2', 'autorouting', 'on');
add_line(path, 'Kd_over_Ts/1', 'pid_voltage_sum/3', 'autorouting', 'on');
add_line(path, 'pid_voltage_sum/1', 'dc_bus_voltage_clamp/1', 'autorouting', 'on');
add_line(path, 'healthy_gain/1', 'fault_derate_gain/1', 'autorouting', 'on');
add_line(path, 'CurrentFault_0to1/1', 'fault_derate_gain/2', 'autorouting', 'on');
add_line(path, 'fault_derate_gain/1', 'fault_gain_clamp/1', 'autorouting', 'on');
add_line(path, 'dc_bus_voltage_clamp/1', 'protected_voltage_cmd/1', 'autorouting', 'on');
add_line(path, 'fault_gain_clamp/1', 'protected_voltage_cmd/2', 'autorouting', 'on');
add_line(path, 'protected_voltage_cmd/1', 'VoltageCmd_V/1', 'autorouting', 'on');
hideInternalBlockNames(path);
end

function populatePwmSubsystem(path)
emptySubsystem(path);
addInport(path, 'VoltageCmd_V', [35 80 65 100]);
add_block('simulink/Math Operations/Gain', [path '/normalize_by_dc_bus'], 'Gain', '1/Vdc_V', ...
    'Position', [120 75 205 105]);
add_block('simulink/Discontinuities/Saturation', [path '/signed_duty_clamp'], ...
    'UpperLimit', '1', 'LowerLimit', '-1', 'Position', [235 75 315 105]);
add_block('simulink/Discontinuities/Dead Zone', [path '/dead_time_equivalent'], ...
    'LowerValue', '-0.02', 'UpperValue', '0.02', 'Position', [365 75 450 105]);
add_block('simulink/Discrete/Zero-Order Hold', [path '/epwm_sample_hold'], ...
    'SampleTime', 'Ts_ctrl', 'Position', [495 75 570 105]);
addOutport(path, 'BridgeDuty', [630 82 660 102]);
add_line(path, 'VoltageCmd_V/1', 'normalize_by_dc_bus/1');
add_line(path, 'normalize_by_dc_bus/1', 'signed_duty_clamp/1');
add_line(path, 'signed_duty_clamp/1', 'dead_time_equivalent/1');
add_line(path, 'dead_time_equivalent/1', 'epwm_sample_hold/1');
add_line(path, 'epwm_sample_hold/1', 'BridgeDuty/1');
end

function populateMotorPlantSubsystem(path)
emptySubsystem(path);
addInport(path, 'BridgeDuty', [35 90 65 110]);
add_block('simulink/Math Operations/Gain', [path '/dc_bus_voltage'], 'Gain', 'Vdc_V', ...
    'Position', [110 85 180 115]);
add_block('simulink/Continuous/Transfer Fcn', [path '/armature_electrical_dynamics'], ...
    'Numerator', '[1]', 'Denominator', '[ArmatureL_H ArmatureR_Ohm]', 'Position', [230 78 380 122]);
add_block('simulink/Math Operations/Gain', [path '/torque_constant'], 'Gain', 'TorqueConstant_Nm_per_A', ...
    'Position', [430 85 525 115]);
add_block('simulink/Sources/Step', [path '/load_torque_step'], 'Time', 'LoadStepTime_s', ...
    'Before', '0', 'After', 'LoadTorque_Nm', 'Position', [430 155 505 185]);
add_block('simulink/Math Operations/Sum', [path '/torque_minus_load'], 'Inputs', '+-', ...
    'Position', [570 92 600 128]);
add_block('simulink/Continuous/Transfer Fcn', [path '/mechanical_dynamics'], ...
    'Numerator', '[1]', 'Denominator', '[RotorInertia_kgm2 ViscousFriction_Nm_s]', 'Position', [650 82 800 122]);
add_block('simulink/Math Operations/Gain', [path '/radps_to_rpm'], 'Gain', '60/(2*pi)', ...
    'Position', [845 85 930 115]);
add_block('simulink/Sources/Constant', [path '/bus_voltage_telemetry'], 'Value', 'Vdc_V', ...
    'Position', [845 205 920 235]);
add_block('simulink/Signal Routing/Mux', [path '/plant_telemetry_mux'], 'Inputs', '3', ...
    'Position', [990 100 1025 220]);
addOutport(path, 'PlantTelemetry', [1085 152 1115 172]);
add_line(path, 'BridgeDuty/1', 'dc_bus_voltage/1');
add_line(path, 'dc_bus_voltage/1', 'armature_electrical_dynamics/1');
add_line(path, 'armature_electrical_dynamics/1', 'torque_constant/1');
add_line(path, 'torque_constant/1', 'torque_minus_load/1');
add_line(path, 'load_torque_step/1', 'torque_minus_load/2');
add_line(path, 'torque_minus_load/1', 'mechanical_dynamics/1');
add_line(path, 'mechanical_dynamics/1', 'radps_to_rpm/1');
add_line(path, 'radps_to_rpm/1', 'plant_telemetry_mux/1');
add_line(path, 'armature_electrical_dynamics/1', 'plant_telemetry_mux/2');
add_line(path, 'bus_voltage_telemetry/1', 'plant_telemetry_mux/3');
add_line(path, 'plant_telemetry_mux/1', 'PlantTelemetry/1');
end

function populateSensorSubsystem(path)
emptySubsystem(path);
addInport(path, 'PlantTelemetry', [35 110 65 130]);
add_block('simulink/Signal Routing/Demux', [path '/telemetry_demux'], 'Outputs', '3', ...
    'Position', [115 78 150 170]);
add_block('simulink/Discontinuities/Quantizer', [path '/qep_speed_quantization'], ...
    'QuantizationInterval', '0.5', 'Position', [210 55 300 85]);
add_block('simulink/Discrete/Unit Delay', [path '/qep_sample_delay'], ...
    'SampleTime', 'Ts_ctrl', 'Position', [350 55 420 85]);
add_block('simulink/Math Operations/Abs', [path '/adc_current_abs'], ...
    'Position', [210 112 260 142]);
add_block('simulink/Math Operations/Gain', [path '/current_limit_ratio'], 'Gain', '1/CurrentLimit_A', ...
    'Position', [310 108 405 146]);
add_block('simulink/Discontinuities/Saturation', [path '/current_fault_0to1'], ...
    'UpperLimit', '1', 'LowerLimit', '0', 'Position', [455 110 535 145]);
addOutport(path, 'MeasuredSpeed_rpm', [605 62 635 82]);
addOutport(path, 'CurrentFault_0to1', [605 120 635 140]);
add_line(path, 'PlantTelemetry/1', 'telemetry_demux/1');
add_line(path, 'telemetry_demux/1', 'qep_speed_quantization/1');
add_line(path, 'qep_speed_quantization/1', 'qep_sample_delay/1');
add_line(path, 'qep_sample_delay/1', 'MeasuredSpeed_rpm/1');
add_line(path, 'telemetry_demux/2', 'adc_current_abs/1');
add_line(path, 'adc_current_abs/1', 'current_limit_ratio/1');
add_line(path, 'current_limit_ratio/1', 'current_fault_0to1/1');
add_line(path, 'current_fault_0to1/1', 'CurrentFault_0to1/1');
end

function populateVideoSubsystem(path)
emptySubsystem(path);
add_block('simulink/Sources/Constant', [path '/raw_720p25_stream'], 'Value', 'RawVideo_Mbps', ...
    'Position', [35 65 120 95]);
add_block('simulink/Math Operations/Gain', [path '/h264_payload_ratio'], 'Gain', 'VideoPayloadNominal_Mbps/RawVideo_Mbps', ...
    'Position', [185 60 315 100]);
add_block('simulink/Sources/Constant', [path '/available_rf_capacity'], 'Value', 'RFVideoCapacity_Mbps-ControlOverhead_Mbps', ...
    'Position', [185 155 315 185]);
add_block('simulink/Math Operations/Sum', [path '/buffer_rate_mbps'], 'Inputs', '+-', ...
    'Position', [375 92 405 132]);
add_block('simulink/Discrete/Discrete-Time Integrator', [path '/frame_buffer_integrator'], ...
    'gainval', '1/8', 'SampleTime', 'Ts_video', 'InitialCondition', 'InitialBuffer_MB', ...
    'Position', [465 92 580 132]);
add_block('simulink/Discontinuities/Saturation', [path '/buffer_capacity_limit'], ...
    'UpperLimit', 'BufferCapacity_MB', 'LowerLimit', '0', 'Position', [635 92 725 132]);
addOutport(path, 'VideoPayload_Mbps', [790 70 820 90]);
addOutport(path, 'BufferLevel_MB', [790 112 820 132]);
add_line(path, 'raw_720p25_stream/1', 'h264_payload_ratio/1');
add_line(path, 'h264_payload_ratio/1', 'buffer_rate_mbps/1');
add_line(path, 'available_rf_capacity/1', 'buffer_rate_mbps/2');
add_line(path, 'buffer_rate_mbps/1', 'frame_buffer_integrator/1');
add_line(path, 'frame_buffer_integrator/1', 'buffer_capacity_limit/1');
add_line(path, 'h264_payload_ratio/1', 'VideoPayload_Mbps/1');
add_line(path, 'buffer_capacity_limit/1', 'BufferLevel_MB/1');
end

function populateRfSubsystem(path)
emptySubsystem(path);
addInport(path, 'VideoPayload_Mbps', [35 92 65 112]);
addInport(path, 'BufferLevel_MB', [35 160 65 180]);
add_block('simulink/Sources/Constant', [path '/nominal_rf_capacity'], 'Value', 'RFVideoCapacity_Mbps-ControlOverhead_Mbps', ...
    'Position', [90 35 225 65]);
add_block('simulink/Math Operations/Sum', [path '/capacity_residual_mbps'], 'Inputs', '+-', ...
    'Position', [285 83 315 123]);
add_block('simulink/Math Operations/Gain', [path '/residual_to_health'], 'Gain', '1/10', ...
    'Position', [370 88 455 118]);
add_block('simulink/Math Operations/Gain', [path '/buffer_pressure'], 'Gain', '1/BufferCapacity_MB', ...
    'Position', [190 155 300 185]);
add_block('simulink/Math Operations/Sum', [path '/health_minus_pressure'], 'Inputs', '+-', ...
    'Position', [515 100 545 140]);
add_block('simulink/Discontinuities/Saturation', [path '/packet_health_0to1'], ...
    'UpperLimit', '1', 'LowerLimit', '0', 'Position', [600 102 690 138]);
add_block('simulink/Sources/Constant', [path '/snr_margin_db'], 'Value', 'MinVideoSNR_dB', ...
    'Position', [600 190 690 220]);
addOutport(path, 'LinkHealth', [760 110 790 130]);
addOutport(path, 'SNRMargin_dB', [760 198 790 218]);
add_line(path, 'nominal_rf_capacity/1', 'capacity_residual_mbps/1');
add_line(path, 'VideoPayload_Mbps/1', 'capacity_residual_mbps/2');
add_line(path, 'capacity_residual_mbps/1', 'residual_to_health/1');
add_line(path, 'BufferLevel_MB/1', 'buffer_pressure/1');
add_line(path, 'residual_to_health/1', 'health_minus_pressure/1');
add_line(path, 'buffer_pressure/1', 'health_minus_pressure/2');
add_line(path, 'health_minus_pressure/1', 'packet_health_0to1/1');
add_line(path, 'packet_health_0to1/1', 'LinkHealth/1');
add_line(path, 'snr_margin_db/1', 'SNRMargin_dB/1');
end

function populateMonitorSubsystem(path)
emptySubsystem(path);
addInport(path, 'MeasuredSpeed_rpm', [35 40 65 60]);
addInport(path, 'CurrentFault_0to1', [35 85 65 105]);
addInport(path, 'VideoPayload_Mbps', [35 130 65 150]);
addInport(path, 'BufferLevel_MB', [35 175 65 195]);
addInport(path, 'LinkHealth', [35 220 65 240]);
addInport(path, 'SNRMargin_dB', [35 265 65 285]);
add_block('simulink/Signal Routing/Mux', [path '/metric_vector_mux'], 'Inputs', '6', ...
    'Position', [145 68 180 258]);
add_block('simulink/Sinks/To Workspace', [path '/system_metrics_to_workspace'], ...
    'VariableName', 'sim_metrics', 'SaveFormat', 'Timeseries', 'Position', [250 140 390 180]);
add_block('simulink/Sinks/Scope', [path '/engineering_scope'], ...
    'Position', [250 215 335 255]);
add_line(path, 'MeasuredSpeed_rpm/1', 'metric_vector_mux/1');
add_line(path, 'CurrentFault_0to1/1', 'metric_vector_mux/2');
add_line(path, 'VideoPayload_Mbps/1', 'metric_vector_mux/3');
add_line(path, 'BufferLevel_MB/1', 'metric_vector_mux/4');
add_line(path, 'LinkHealth/1', 'metric_vector_mux/5');
add_line(path, 'SNRMargin_dB/1', 'metric_vector_mux/6');
add_line(path, 'metric_vector_mux/1', 'system_metrics_to_workspace/1');
add_line(path, 'metric_vector_mux/1', 'engineering_scope/1');
end

function smoke = runSimulinkSmokeTest(modelName)
smoke = struct();
smoke.requested = true;
smoke.passed = false;
smoke.stop_time_s = 0.25;
smoke.method = 'Simulink.SimulationInput';
smoke.error = '';
smoke.logged_variables = {};
try
    in = Simulink.SimulationInput(modelName);
    in = in.setModelParameter('StopTime', num2str(smoke.stop_time_s));
    out = sim(in);
    smoke.passed = true;
    try
        smoke.logged_variables = cellstr(out.who);
    catch
        smoke.logged_variables = {};
    end
catch err
    smoke.error = err.message;
end
fprintf('Simulink smoke test passed: %d\n', smoke.passed);
end

function architectureReview = summarizeSimulinkArchitecture(modelName, params, smoke, agenticStatus)
subsystems = {
    'Command_Scheduler';
    'DSP_Control_Algorithm';
    'PWM_Gate_Driver_HBridge';
    'DC_Motor_Electromechanical_Plant';
    'ADC_QEP_Sensor_Acquisition';
    'Video_Capture_Codec_Buffer';
    'VHF_RF_Transceiver_Channel';
    'Supervisor_Performance_Monitors'};
blocks = find_system(modelName, 'LookUnderMasks', 'on', 'FollowLinks', 'on', 'Type', 'Block');
architectureReview = struct();
architectureReview.model = modelName;
architectureReview.generated_at = datestr(now, 31);
architectureReview.matlab_version = version;
architectureReview.agentic_toolkit_initialized = agenticStatus.initialized;
architectureReview.agentic_skills_applied = agenticStatus.skills_applied;
architectureReview.subsystems = subsystems;
architectureReview.block_count = numel(blocks);
architectureReview.line_count = countLinesRecursive(modelName);
architectureReview.model_workspace_variables = {
    'Ts_ctrl'; 'Ts_video'; 'ForwardSpeed_rpm'; 'ReverseDelta_rpm'; 'Vdc_V';
    'Kp_speed'; 'Ki_speed'; 'Kd_over_Ts'; 'CurrentLimit_A'; 'RawVideo_Mbps';
    'VideoPayloadNominal_Mbps'; 'RFVideoCapacity_Mbps'; 'BufferCapacity_MB';
    'MinVideoSNR_dB'};
architectureReview.interfaces = {
    'SpeedRef_rpm -> DSP_Control_Algorithm';
    'MeasuredSpeed_rpm and CurrentFault_0to1 feedback -> DSP_Control_Algorithm';
    'BridgeDuty -> DC_Motor_Electromechanical_Plant';
    'VideoPayload_Mbps and BufferLevel_MB -> VHF_RF_Transceiver_Channel';
    'Six-channel metric vector -> Supervisor_Performance_Monitors'};
architectureReview.simulation_smoke_test = smoke;
architectureReview.numeric_source = 'MATLAB script simulation outputs remain the source of report metrics; Simulink smoke simulation verifies structural executability.';
architectureReview.key_parameters = struct( ...
    'motor_sample_time_s', params.motor.sample_time_s, ...
    'target_speed_rpm', params.motor.target_speed_rpm, ...
    'video_nominal_payload_mbps', params.video.mean_payload_mbps, ...
    'rf_video_capacity_mbps', params.video.rf_capacity_mbps);
end

function n = countLinesRecursive(scope)
n = 0;
systems = find_system(scope, 'LookUnderMasks', 'on', 'FollowLinks', 'on', 'BlockType', 'SubSystem');
systems = [{scope}; systems(:)];
for i = 1:numel(systems)
    try
        lines = get_param(systems{i}, 'Lines');
        n = n + numel(lines);
    catch
    end
end
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

function hideInternalBlockNames(path)
blocks = find_system(path, 'SearchDepth', 1, 'Type', 'Block');
for i = 1:numel(blocks)
    if strcmp(blocks{i}, path)
        continue;
    end
    blockType = get_param(blocks{i}, 'BlockType');
    if ~ismember(blockType, {'Inport', 'Outport'})
        try
            set_param(blocks{i}, 'ShowName', 'off');
        catch
        end
    end
end
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
