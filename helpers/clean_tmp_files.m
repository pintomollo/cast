function clean_tmp_files()
% CLEAN_TMP_FILES removes all unused data in TmpData by recursively parsing the
% content of the .mat files present in the current directory.

  ls_dir = dir('*.mat'); 
  nfiles = length(ls_dir);
  used_tmp = [];

  hwait = waitbar(0,'','Name','Cleaning TmpData','Visible','off');
  waitbar(0, hwait, ['Parsing .mat files to identify used data...']);
  set(hwait, 'Visible', 'on');
  for i=1:nfiles
    data = load(ls_dir(i).name);

    if (~isfield(data, 'mytracking'))
      continue;
    end
    tmp_tmp = recursive_tmp(data.mytracking);
    used_tmp = [used_tmp; tmp_tmp];

    waitbar(i/nfiles,hwait);
  end
  used_tmp = unique(used_tmp);

  cd_dir = [pwd filesep];
  if (exist('TmpData', 'dir'))
    tmp_dir = [cd_dir 'TmpData' filesep];
  else
    tmp_dir = cd_dir;
  end

  ls_dir = dir([tmp_dir 'tmpmat*']);
  nfiles = length(ls_dir);
  waitbar(0, hwait, ['Parsing TmpData to identify existing data...']);
  removed_files = {};
  for d = 1:nfiles
    [tmp tokens] = regexp(ls_dir(d).name,'tmpmat(\d+)\.*','match','tokens');
    if(length(tokens)~=0)
      tmp_token = str2double(char(tokens{1}));
      if (~any(used_tmp == tmp_token))
        removed_files(end+1) = {ls_dir(d).name};
      end
    end
    waitbar(d/nfiles,hwait);
  end
  set(hwait, 'Visible', 'off');

  if (~isempty(removed_files))
    answer = questdlg([{'The following files will be permanently deleted because they are not used by any project file:'};{''}; removed_files(:); {''}; 'Proceed ?'], 'Confirm deletion of temporary files');

    if (strcmp(answer, 'Yes'))
      waitbar(0, hwait, ['Deleting temporary data...']);
      set(hwait, 'Visible', 'on');
      nfiles = length(removed_files);
      for i=1:nfiles
        delete([tmp_dir removed_files{i}]);
        waitbar(i/nfiles,hwait);
      end
    end
  else
    warndlg('TmpData is already clean !', 'Cleaning TmpData');
  end

  close(hwait);

  return;
end

function tmps = recursive_tmp(mystruct)

  tmps = [];
  used_tmp = [];

  fields = fieldnames(mystruct);

  indx = ismember(fields, 'fname');

  if (any(indx))
    [tmp tokens] = regexp(mystruct.fname,'tmpmat(\d+)\.*','match','tokens');
    if (length(tokens)~=0)
      used_tmp = [used_tmp; str2double(char(tokens{1}))];

      if (~exist(mystruct.fname, 'file'))
        display(['Missing ' mystruct.fname]);
      end
    end

    fields = fields(~indx);
  end

  for j=1:length(fields)
    if (isstruct(mystruct.(fields{j})))
      for k=1:length(mystruct.(fields{j}))
        if (k==1)
          sub_fields = fieldnames(mystruct.(fields{j})(k));
          has_struct = any(ismember(sub_fields, 'file'));
          if (~has_struct)
            for s = 1:length(sub_fields)
              if (isstruct(mystruct.(fields{j})(k).(sub_fields{s})))
                has_struct = true;
                break;
              end
            end
          end
        end

        if (has_struct)
          tmp_tmp = recursive_tmp(mystruct.(fields{j})(k));

          tmps = [tmps; tmp_tmp];
        end
      end
    end
  end

  tmps = [tmps; used_tmp];

  return;
end
