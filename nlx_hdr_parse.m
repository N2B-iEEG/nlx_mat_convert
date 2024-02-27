function hdr_struct = nlx_hdr_parse(hdr_txt)

hdr_struct = struct();

for line_cell = hdr_txt'
    line = string(line_cell{1});

    if ~isempty(line) && startsWith(line, '-')

        field_name = extractBetween(line, '-', ' ');
        if strcmp(field_name, 'DspFilterDelay_µs')
            field_name = 'DspFilterDelay_micro_sec';
        end

        field_value = char(extractAfter(line, ' '));

        if startsWith(field_value, '"') && endsWith(field_value, '"')
            field_value = field_value(2:end-1);
        end
        
        if ~isnan(str2double(field_value))
            field_value = str2double(field_value);
        end

        hdr_struct.(field_name) = field_value;

    end

end

end