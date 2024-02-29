% Segment and save Nerualynx data (.nev and .ncs) based on segment start
% and end timestamp (Unix time)

function nlx_seg(nlx_dir, seg_dir, seg_start_ts, seg_end_ts)

% Works only on Windows/Unix
if ~ispc && ~isunix
    error('Nlx2Mat is only available on Windows/Linux/MacOS\n')
end

% Create seg_dir if not already
if ~exist(seg_dir, 'dir')
    mkdir(seg_dir)
end

seg_nev = fullfile(seg_dir, 'Events.nev');
if exist(seg_nev, 'file')
    delete(seg_nev)
end

fprintf(['Segmenting Neuralynx data to%s\n' ...
    '========================================\n'], ...
    seg_dir)

%% Find all events and segment
nev_files = dir(fullfile(nlx_dir, '*.nev'));

% Exclude header-only files
nev_files = nev_files([nev_files.bytes] ~= 16384);

% Warning if no valid events file was found
if isempty(nev_files)
    warning('No .nev event file found in: %s\n', ...
        nlx_dir)
else
    % Get events from all .nev files
    EventTable = table();
    for nev = nev_files'
        nev_path = fullfile(nev.folder, nev.name);
        events_this = nlx_read_full(nev_path);
        EventTable = [EventTable; events_this.EventTable];
        fprintf('Valid event file %s\n', nev.name)
    end
    Header = events_this.Header;
    Header{6} = '-OriginalFileName SegmentedEventFile';
    Header{7} = sprintf('-TimeCreated %s', ...
        string(datetime('now'), 'yyyy/MM/dd hh:mm:ss'));
    Header{8} = sprintf('-TimeClosed %s', ...
        string(datetime('now'), 'yyyy/MM/dd hh:mm:ss'));
    EventTable = sortrows(EventTable, 'TimeStamps', 'ascend');
    within_seg = (EventTable.TimeStamps >= seg_start_ts) & ...
        (EventTable.TimeStamps <= seg_end_ts);
    EventTable = EventTable(within_seg,:);

    % Write segmented events to seg_dir
    if isunix
        % Unix version requires additional input argument `NumRecs`
        Mat2NlxEV(char(seg_nev), 0, 1, [], length(EventTable.TimeStamps), ...
            [1 1 1 1 1 1], ...
            EventTable.TimeStamps', ...
            EventTable.EventIDs', ...
            EventTable.TTLs', ...
            EventTable.Extras', ...
            EventTable.EventStrings, ...
            Header);
    elseif ispc
        Mat2NlxEV(char(seg_nev), 0, 1, [], ...
            [1 1 1 1 1 1], ...
            EventTable.TimeStamps', ...
            EventTable.EventIDs', ...
            EventTable.TTLs', ...
            EventTable.Extras', ...
            EventTable.EventStrings, ...
            Header);
    end
    fprintf('Segmented .nev exported to %s\n', seg_nev)
end

%% Find and segment all recordings
ncs_files = dir(fullfile(nlx_dir, '*.ncs'));

% Exclude header-only files
ncs_files = ncs_files([ncs_files.bytes] ~= 16384);

% Warning if no valid recording file was found
if isempty(ncs_files)
    warning('No .ncs recording file found in: %s\n', ...
        nlx_dir)
else
    % First loop to determine unique channels
    ncs_table = table();
    for ncs = ncs_files'
        ncs_path = fullfile(ncs.folder, ncs.name);
        if isunix
            hdr_txt = Nlx2MatCSC_v3(ncs_path, ...
                [0 0 0 0 0], 1, 3, 1);
        elseif ispc
            hdr_txt = Nlx2MatCSC(ncs_path, ...
                [0 0 0 0 0], 1, 3, 1);
        end

        hdr_struct = nlx_hdr_parse(hdr_txt);
        ch_name    = string(hdr_struct.AcqEntName);

        % Append new row
        ncs_table = [ncs_table; {ncs_path, ch_name}];
        fprintf('Channel %s has a recording file %s\n', ch_name, ncs.name)
    end

    ch_name_all = unique(ncs_table.Var2);

    % Second loop to gather data from all .ncs with the same channel name
    % and segment
    for ch = ch_name_all'
        seg_ch_ncs = fullfile(seg_dir, strcat(ch, '.ncs'));
        if exist(seg_ch_ncs, 'file')
            delete(seg_ch_ncs)
        end
        SampTable = table();
        ch_files = table2cell(ncs_table(strcmp(ncs_table.Var2,ch), 1));
        for ch_file = ch_files'
            ch_file = ch_file{1};
            ch_data_this = nlx_read_full(ch_file);
            SampTable = [SampTable; ch_data_this.SampTable];
        end
        Header = ch_data_this.Header;
        Header{7} = '-OriginalFileName SegmentedRecordingFile';
        Header{8} = sprintf('-TimeCreated %s', ...
            string(datetime('now'), 'yyyy/MM/dd hh:mm:ss'));
        Header{9} = sprintf('-TimeClosed %s', ...
            string(datetime('now'), 'yyyy/MM/dd hh:mm:ss'));
        SampTable = sortrows(SampTable, 'TimeStamps', 'ascend');
        within_seg = (SampTable.TimeStamps >= seg_start_ts) & ...
            (SampTable.TimeStamps <= seg_end_ts + ...
            512 / ch_data_this.HeaderStruct.SamplingFrequency * 1e6);
        SampTable = SampTable(within_seg,:);

        ts_diff = diff(SampTable.TimeStamps);
        if max(ts_diff) > 5 * 512 / ch_data_this.HeaderStruct.SamplingFrequency * 1e6
            warning('May not be a contineous recording')
        end

        % Write segmented channel data
        if isunix
            % Unix version requires additional input argument `NumRecs`
            Mat2NlxCSC(char(seg_ch_ncs), 0, 1, [], length(SampTable.TimeStamps), ...
                [1 1 1 1 1 1], ...
                SampTable.TimeStamps', ...
                SampTable.ChannelNumbers', ...
                SampTable.SampleFrequencies', ...
                SampTable.NumberOfValidSamples', ...
                SampTable.Samples', ...
                Header);
        elseif ispc
            Mat2NlxCSC(char(seg_ch_ncs), 0, 1, [], ...
                [1 1 1 1 1 1], ...
                SampTable.TimeStamps', ...
                SampTable.ChannelNumbers', ...
                SampTable.SampleFrequencies', ...
                SampTable.NumberOfValidSamples', ...
                SampTable.Samples', ...
                Header);
        end
        fprintf('Segmented .ncs exported to %s\n', seg_ch_ncs)
    end
end

end