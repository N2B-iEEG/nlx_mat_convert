% Segment and save Nerualynx data (.nev and .ncs) based on a run table
% `run_table`

function nlx_seg(nlx_dir, run_table, ch_excl)

% Works only on Windows/Unix
if ~ispc && ~isunix
    error('Nlx2Mat is only available on Windows/Linux/MacOS\n')
end

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

    % Segment events run by run
    for i_run = 1:size(run_table, 1)

        run_name = run_table.run_name(i_run);
        seg_dir = fullfile(nlx_dir, run_name);

        seg_start_ts = run_table.start_ts(i_run);
        seg_end_ts   = run_table.end_ts(i_run);

        % Create seg_dir if not already
        if ~exist(seg_dir, 'dir')
            mkdir(seg_dir)
        end

        seg_nev = fullfile(seg_dir, 'Events.nev');
        if exist(seg_nev, 'file')
            delete(seg_nev)
        end

        within_seg = (EventTable.TimeStamps >= seg_start_ts) & ...
            (EventTable.TimeStamps <= seg_end_ts);
        EventTableSeg = EventTable(within_seg,:);

        % Write segmented events to seg_dir
        if isunix
            % Unix version requires additional input argument `NumRecs`
            Mat2NlxEV(char(seg_nev), 0, 1, [], length(EventTableSeg.TimeStamps), ...
                [1 1 1 1 1 1], ...
                EventTableSeg.TimeStamps', ...
                EventTableSeg.EventIDs', ...
                EventTableSeg.TTLs', ...
                EventTableSeg.Extras', ...
                EventTableSeg.EventStrings, ...
                Header);
        elseif ispc
            Mat2NlxEV(char(seg_nev), 0, 1, [], ...
                [1 1 1 1 1 1], ...
                EventTableSeg.TimeStamps', ...
                EventTableSeg.EventIDs', ...
                EventTableSeg.TTLs', ...
                EventTableSeg.Extras', ...
                EventTableSeg.EventStrings, ...
                Header);
        end
        fprintf('Segmented .nev exported to %s\n', seg_nev)
    end
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
    ch_name_all = ch_name_all(~ismember(ch_name_all, ch_excl));

    % Second loop to gather data from all .ncs with the same channel name
    % and segment run by run

    for ch = ch_name_all'

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

        for i_run = 1:size(run_table, 1)

            run_name = run_table.run_name(i_run);
            seg_dir = fullfile(nlx_dir, run_name);

            seg_start_ts = run_table.start_ts(i_run);
            seg_end_ts   = run_table.end_ts(i_run);

            seg_ch_ncs = fullfile(seg_dir, strcat(ch, '.ncs'));
            if exist(seg_ch_ncs, 'file')
                delete(seg_ch_ncs)
            end

            % Time difference between each contineous data sample (in microsec)
            samp_ts = 512 / ch_data_this.HeaderStruct.SamplingFrequency * 1e6;

            within_seg = (SampTable.TimeStamps >= seg_start_ts - 3 * samp_ts) & ...
                (SampTable.TimeStamps <= seg_end_ts + 4 * samp_ts);
            SampTableSeg = SampTable(within_seg,:);

            if SampTableSeg.TimeStamps(1) - seg_start_ts > 0
                warning('Recording starts after run start TTL')
            end

            if SampTableSeg.TimeStamps(end) - seg_end_ts < samp_ts
                warning('Recording ends before run end TTL')
            end

            ts_diff = diff(SampTableSeg.TimeStamps);
            if max(ts_diff) > 5 * 512 / ch_data_this.HeaderStruct.SamplingFrequency * 1e6
                warning('May not be a contineous recording')
            end

            % Write segmented channel data
            if isunix
                % Unix version requires additional input argument `NumRecs`
                Mat2NlxCSC(char(seg_ch_ncs), 0, 1, [], length(SampTableSeg.TimeStamps), ...
                    [1 1 1 1 1 1], ...
                    SampTableSeg.TimeStamps', ...
                    SampTableSeg.ChannelNumbers', ...
                    SampTableSeg.SampleFrequencies', ...
                    SampTableSeg.NumberOfValidSamples', ...
                    SampTableSeg.Samples', ...
                    Header);
            elseif ispc
                Mat2NlxCSC(char(seg_ch_ncs), 0, 1, [], ...
                    [1 1 1 1 1 1], ...
                    SampTableSeg.TimeStamps', ...
                    SampTableSeg.ChannelNumbers', ...
                    SampTableSeg.SampleFrequencies', ...
                    SampTableSeg.NumberOfValidSamples', ...
                    SampTableSeg.Samples', ...
                    Header);
            end
            fprintf('Segmented .ncs exported to %s\n', seg_ch_ncs)
        end
    end
end

end