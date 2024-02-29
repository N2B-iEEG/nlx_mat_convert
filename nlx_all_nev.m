function EventTable = nlx_all_nev(nlx_dir)

% Works only on Windows/Unix
if ~ispc && ~isunix
    error('Nlx2Mat is only available on Windows/Linux/MacOS\n')
end

%% Find and merge all events
nev_files = dir(fullfile(nlx_dir, '*.nev'));

% Exclude header-only files
nev_files = nev_files([nev_files.bytes] ~= 16384);

% Warning if no valid recording file was found
if isempty(nev_files)
    error('No .nev event file found in: %s\n', ...
        nlx_dir)
end

% Get events from all .nev files
EventTable = table();
for nev = nev_files'
    nev_path = fullfile(nev.folder, nev.name);
    events_this = nlx_read_full(nev_path);
    EventTable = [EventTable; events_this.EventTable];
    fprintf('Valid event file %s\n', nev.name)
end
EventTable = sortrows(EventTable, 'TimeStamps', 'ascend');

end