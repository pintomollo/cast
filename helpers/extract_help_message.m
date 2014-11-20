function [name, curr_fields] = extract_help_message(mystruct)
% EXTRACT_HELP_MESSAGE reads the help message corresponding to the provided structure.
% The help messages are the corresponding comments at the end of the line defining
% the structure field in get_struct.m.
%
%   [NAME, HELP] = EXTRACT_HELP_MESSAGE(MYSTRUCT) returns the NAME of MYSTRUCT as found
%   in get_struct.m, and the HELP for all the fields found as a cell array.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 28.08.2014

  % Find the correct file
  fname = which('get_struct.m');

  % We open it in text mode 
  fid = fopen(fname,'rt');

  % Initialize the output values
  name = '';
  tmp_fields = cell(0, 2);
  curr_fields = tmp_fields;

  % The current fields in the structure we received, for comparison
  fields = fieldnames(mystruct);

  % We loop throughout the file, line by line
  line = fgetl(fid);
  skipping = true;
  while ischar(line)

    % We remove unsignificant white spaces
    line = strtrim(line);

    % We ignore empty lines and comment lines
    if (length(line) > 0 && line(1) ~= '%')

      % We first look for new structures
      tokens = regexp(line, 'case ''(.+)''','tokens');

      % We found one !
      if (~isempty(tokens))
        % If we have something stored, it means we found our structure, so stop here
        if (~isempty(curr_fields) & ~skipping)
          break;
        end

        % Otherwise, we store the current name and prepare the new values
        tmp_name = tokens{1}{1};
        curr_fields = tmp_fields;
        skipping = false;

      % If we are not skipping this whole structure, we can read the comments
      elseif (~skipping)

        % Get the field name and comments
        tokens = regexp(line, '[^'']*''([^,'']+)''\s*,[^%]*%\s*(.+)','tokens');

        % If we got something, we check whether it is part of the current structure
        if (~isempty(tokens))
          curr_field = tokens{1};

          % If not, we skip the entire structure
          if (~ismember(fields, curr_field{1}))
            skipping = true;

          % Otherwise we store it !
          else
            name = tmp_name;
            curr_fields(end+1,:) = tokens{1};
          end
        end
      end
    end

    % Process the next line
    line = fgetl(fid);
  end

  % And close the file
  fclose(fid);

  % Add empty help for the missing fields
  missing = ~ismember(fields, curr_fields(:,1));
  if (any(missing))
    curr_fields = [curr_fields; [fields(missing) cellstr(repmat(' ',sum(missing), 1))]];
  end

  return;
end
