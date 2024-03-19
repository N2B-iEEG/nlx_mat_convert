% Read all data and header from a Neuralynx file (.nev or .ncs)

function output = nlx_read_full(FileName)

if ~ispc && ~isunix
    error('Nlx2Mat is only available on Windows/Linux/MacOS\n')
end

FileName = char(FileName);

output = struct();

% Determine file extension
[~, ~, ext] = fileparts(FileName);

if strcmp(ext, '.nev')
    if isunix
        [TimeStamps, ...
            EventIDs, ...
            TTLs, ...
            Extras, ...
            EventStrings, ...
            output.Header] = Nlx2MatEV_v3( ...
            FileName, ...
            [1 1 1 1 1], 1, 1, []);
    elseif ispc
        [TimeStamps, ...
            EventIDs, ...
            TTLs, ...
            Extras, ...
            EventStrings, ...
            output.Header] = Nlx2MatEV( ...
            FileName, ...
            [1 1 1 1 1], 1, 1, []);
    end

    EventTable = table(TimeStamps', EventIDs', TTLs', Extras', EventStrings, ...
        'VariableNames', {'TimeStamps', 'EventIDs', 'TTLs', 'Extras', 'EventStrings'});
    EventTable = sortrows(EventTable, 'TimeStamps', 'ascend');
    output.EventTable = EventTable;

elseif strcmp(ext, '.ncs')

    if isunix
        [TimeStamps, ...
            ChannelNumbers, ...
            SampleFrequencies, ...
            NumberOfValidSamples, ...
            Samples, ...
            output.Header] = Nlx2MatCSC_v3( ...
            FileName, [1 1 1 1 1], 1, 1, []);
    elseif ispc
        [TimeStamps, ...
            ChannelNumbers, ...
            SampleFrequencies, ...
            NumberOfValidSamples, ...
            Samples, ...
            output.Header] = Nlx2MatCSC( ...
            FileName, [1 1 1 1 1], 1, 1, []);
    end

    SampTable = table(TimeStamps', ChannelNumbers', SampleFrequencies', NumberOfValidSamples', Samples', ...
        'VariableNames', {'TimeStamps', 'ChannelNumbers', 'SampleFrequencies', 'NumberOfValidSamples', 'Samples'});
    SampTable = sortrows(SampTable, 'TimeStamps', 'ascend');
    output.SampTable = SampTable;

else
    error('nlx_read_all currently only supports reading .nev and .ncs files')
end

output.HeaderStruct = nlx_hdr_parse(output.Header);

end