function save_parameters(opts, fname)

  if (nargin < 2)
    if (exist('Config', 'dir'))
      conf_dir = which('Config.');
    elseif (exist(['cell-tracking' filesep 'Config'], 'dir'))
      conf_dir = ['cell-tracking' filesep 'Config'];
    else
      conf_dir = pwd;
    end

    [fname, pathname] = uiputfile({'*.txt','All text files'; '*.*','All files' }, ...
                                   'Save parameters', [conf_dir filesep]);

    if (all(fname == 0))
      return;
    end

    fname = fullfile(pathname, fname);
  end

  if (isnumeric(fname) & ~isempty(fopen(fname)))
    fid = fname;
  else
    % We open it in text mode 
    fid = fopen(fname,'w+t');

    % If there is an error, maybe we don't have the absolute path
    if (fid<0)
      fname = fullfile(pwd, fname);

      % And if it still does not work, then we skip this file
      fid = fopen(fname,'w+t');
      if (fid<0)
        return;
      end
    end
  end

  spacer = '\t';
  prefix = '';

  fprintf(fid, '%%Parameters saved on %s\n\n', datestr(now));

  try
    myprint(fid, opts, spacer, prefix);
  catch ME
    warning('Tracking:SavingParameters', ['An error occured when saving the parameters:\n' ME.message])
  end

  if (any(fid ~= fname))
    fclose(fid);
  end

  return;
end

function myprint(fid, variable, spacer, prefix)

  orig_prefix = prefix;

  if (isempty(variable))
    fprintf(fid, [prefix spacer '[]\n']);
  else
    switch class(variable)
      case 'cell'
        for i=1:numel(variable)
          myprint(fid, variable{i}, spacer, [prefix '{' num2str(i) '}']);
        end
      case {'struct', 'MException'}
        fields = fieldnames(variable);
        for i=1:numel(variable)
          if (numel(variable) > 1)
            prefix = [orig_prefix '(' num2str(i) ')'];
          end
          for j=1:length(fields)
            name = fields{j};
            values = variable(i).(name);

            if (isempty(prefix))
              myprint(fid, values, spacer, name);
            else
              myprint(fid, values, spacer, [prefix '.' name]);
            end
          end
        end
        fprintf(fid, '\n');
      case {'double', 'single', 'int8', 'int16', 'int32', 'int64', 'uint8', 'uint16', 'uint32', 'uint64'}
        if (numel(variable) == 1)
          fprintf(fid, [prefix spacer '%e\n'], variable);
        else
          fprintf(fid, [prefix spacer '[']);
          fprintf(fid, '%f ', variable);
          fprintf(fid, ']\n');
        end
      case 'logical'
        if (numel(variable) == 1)
          fprintf(fid, [prefix spacer '%d\n'], variable);
        else
          fprintf(fid, [prefix spacer '[']);
          fprintf(fid, '%d ', variable);
          fprintf(fid, ']\n');
        end
      case 'char'
        fprintf(fid, [prefix spacer '''%s''\n'], variable);
      otherwise
        fprintf(fid, [prefix spacer '''%s''\n'], class(variable));
    end
  end
  
  return;
end
