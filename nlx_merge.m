% Merge multiple .nev and .ncs files into a single file
% A new directory `merged` will be created in the input directory

function nlx_merge(nlx_dir)

% Works only on Windows/Unix
if ~ispc && ~isunix
    error('Nlx2Mat is only available on Windows/Linux/MacOS\n')
end

% Directory for merged files
mer_dir = fullfile(nlx_dir, 'merged');
mer_nev = fullfile(mer_dir, 'Events.nev');

if ~exist(mer_dir, 'dir')
    mkdir(mer_dir)
end

if exist(mer_nev, 'file')
    delete(mer_nev)
end

%% Find and merge all events
nev_files = dir(fullfile(nlx_dir, '*.nev'));

% Exclude header-only files
nev_files = nev_files([nev_files.bytes] ~= 16384);

% Warning if no valid recording file was found
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

    % Modify header
    OriginalFileName_idx = startsWith(Header, '-OriginalFileName');
    Header{OriginalFileName_idx} = '-OriginalFileName SegmentedEventFile';

    TimeCreated_idx = startsWith(Header, '-TimeCreated');
    Header{TimeCreated_idx} = sprintf('-TimeCreated %s', ...
        string(datetime('now'), 'yyyy/MM/dd hh:mm:ss'));

    TimeClosed_idx = startsWith(Header, '-TimeClosed');
    Header{TimeClosed_idx} = sprintf('-TimeClosed %s', ...
        string(datetime('now'), 'yyyy/MM/dd hh:mm:ss'));

    EventTable = sortrows(EventTable, 'TimeStamps', 'ascend');

    % Write merged events to `mer_nev`
    if isunix
        % Unix version requires additional input argument `NumRecs`
        Mat2NlxEV(mer_nev, 0, 1, [], length(EventTable.TimeStamps), ...
            [1 1 1 1 1 1], ...
            EventTable.TimeStamps', ...
            EventTable.EventIDs', ...
            EventTable.TTLs', ...
            EventTable.Extras', ...
            EventTable.EventStrings, ...
            Header);
    elseif ispc
        Mat2NlxEV(mer_nev, 0, 1, [], ...
            [1 1 1 1 1 1], ...
            EventTable.TimeStamps', ...
            EventTable.EventIDs', ...
            EventTable.TTLs', ...
            EventTable.Extras', ...
            EventTable.EventStrings, ...
            Header);
    end
    fprintf('Merged .nev exported to %s\n', mer_nev)
end

%% Find and merge all recordings
ncs_files = dir(fullfile(nlx_dir, '*.ncs'));

% Exclude header-only files
ncs_files = ncs_files([ncs_files.bytes] ~= 16384);

% Warning if no valid events file was found
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

    % Second loop to merge all .ncs with the same channel name
    for ch = ch_name_all'
        mer_ch_ncs = char(fullfile(mer_dir, strcat(ch, '.ncs')));
        if exist(mer_ch_ncs, 'file')
            delete(mer_ch_ncs)
        end
        SampTable = table();
        ch_files = table2cell(ncs_table(strcmp(ncs_table.Var2,ch), 1));
        for ch_file = ch_files'
            ch_file = ch_file{1};
            ch_data_this = nlx_read_full(ch_file);
            SampTable = [SampTable; ch_data_this.SampTable];
        end
        Header = events_this.Header;

        % Modify header
        OriginalFileName_idx = startsWith(Header, '-OriginalFileName');
        Header{OriginalFileName_idx} = '-OriginalFileName SegmentedEventFile';

        TimeCreated_idx = startsWith(Header, '-TimeCreated');
        Header{TimeCreated_idx} = sprintf('-TimeCreated %s', ...
            string(datetime('now'), 'yyyy/MM/dd hh:mm:ss'));

        TimeClosed_idx = startsWith(Header, '-TimeClosed');
        Header{TimeClosed_idx} = sprintf('-TimeClosed %s', ...
            string(datetime('now'), 'yyyy/MM/dd hh:mm:ss'));

        SampTable = sortrows(SampTable, 'TimeStamps', 'ascend');

        % Write merged channel data
        if isunix
            % Unix version requires additional input argument `NumRecs`
            Mat2NlxCSC(mer_ch_ncs, 0, 1, [], length(SampTable.TimeStamps), ...
                [1 1 1 1 1 1], ...
                SampTable.TimeStamps', ...
                SampTable.ChannelNumbers', ...
                SampTable.SampleFrequencies', ...
                SampTable.NumberOfValidSamples', ...
                SampTable.Samples', ...
                Header);
        elseif ispc
            Mat2NlxCSC(mer_ch_ncs, 0, 1, [], ...
                [1 1 1 1 1 1], ...
                SampTable.TimeStamps', ...
                SampTable.ChannelNumbers', ...
                SampTable.SampleFrequencies', ...
                SampTable.NumberOfValidSamples', ...
                SampTable.Samples', ...
                Header);
        end
        fprintf('Merged .ncs exported to %s\n', mer_ch_ncs)
    end
end

end