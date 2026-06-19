function setup_agentic_toolkits()
%SETUP_AGENTIC_TOOLKITS Install/configure official MathWorks agentic toolkits.
% Requires the MathWorks Agentic Toolkit Setup add-on to be installed.
% The build does not depend on this helper succeeding silently; real status is
% recorded by run_all_simulations in output/logs/agentic_toolkit_status.json.

fprintf('Checking MathWorks Agentic Toolkit status before install...\n');
assert(exist('setupAgenticToolkit', 'file') ~= 0, ...
    'setupAgenticToolkit is not on path. Install agenticToolkitInstaller.mltbx first.');

try
    setupAgenticToolkit("status");
catch err
    fprintf('setupAgenticToolkit status failed: %s\n', err.message);
end

fprintf('Installing MATLAB and Simulink Agentic Toolkits for Codex project scope...\n');
try
    setupAgenticToolkit("install", ...
        Toolkit=["matlab", "simulink"], ...
        Agents="codex", ...
        Scope="project", ...
        Prompt=false);
catch err
    fprintf('setupAgenticToolkit install did not complete: %s\n', err.message);
    fprintf(['If this is the known MCP Server release-asset rename issue, ', ...
        'download MATLABMCPServerToolbox.mltbx and matlab-mcp-server-windows-x64.exe ', ...
        'from the official matlab-mcp-server release, place the exe under ', ...
        '~/.matlab/agentic-toolkits/bin/, and rerun run_all_simulations.\n']);
end

fprintf('Checking MathWorks Agentic Toolkit status after install...\n');
try
    setupAgenticToolkit("status");
catch err
    fprintf('setupAgenticToolkit status failed: %s\n', err.message);
end
end
