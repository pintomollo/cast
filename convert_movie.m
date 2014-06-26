function [converted_file] = convert_movie(name)
% CONVERT_MOVIE converts a recording such that it can be tracked properly.
%
%   [MYMOVIE] = CONVERT_MOVIE(NAME, OPTS) loads the movie NAME into MYMOVIE
%   using the provided options from OPTS. If NAME is empty, the user will be
%   prompted to choose the adequate file.
%
% Naef labs, EPFL
% Simon Blanchoud
% 01.05.2014

  % Initialization
  converted_file = '';
  curdir = '';
  dirpath = '';
  if (nargin == 0)
    name = '';
  end

  % We got the file to be loaded as input !
  if (ischar(name) & ~isempty(name))

    % Chech whether the file is in a subdirectory
    indx = strfind(name, filesep);

    % If this is the case, separate the path and the name
    if (~isempty(indx))
      dirpath = name(1:indx(end));
      fname = name(indx(end)+1:end);

      % Check whether this is an absolute path or not
      if (dirpath(1) ~= filesep && isempty(strfind(name, ':')))
        dirpath = ['.' filesep dirpath];
      end
    else
      fname = name;
    end
  else

    % In case a subfolder name Movies exists, move into it for prompting
    curdir = '';
    if(exist('Movies', 'dir'))
      curdir = cd;
      cd('Movies');
    elseif(exist(['..' filesep 'Movies'], 'dir'))
      curdir = cd;
      cd(['..' filesep 'Movies']);
    end

    % Fancy output
    disp('[Select a movie file]');

    % Prompting the user for the movie file
    [fname, dirpath] = uigetfile({'*.*'}, ['Load a movie']);
    fname = fullfile(dirpath, fname);
  end

  % Return back to our original folder
  if(~isempty(curdir))
    cd(curdir);
  end

  % If no file was selected, stop here
  if (length(fname) == 0  ||  isequal(dirpath, 0))
    disp(['No movie selected']);
    return;
  end

  % Check the type of the movie chosen
  [file_path, filename, ext] = fileparts(fname);

  % If the user chose a MAT file, load it and stop here
  if (strncmp(ext, '.mat', 4))
    load(fname);
    return;
  end

  % We convert the provided type into a more handy one
  %new_fname = bftools_convert(fname);
  converted_file = bftools_convert(fname);

  % Ask the user to identify the different channels
  %mymovie = identify_channels(new_fname);

  % Use the movie name as the name for the entire experiment
  %mymovie.experiment = name;

  % Rescale the channels (including some filtering)
  %mymovie = rescale_movie(mymovie);

  return;
end

% Here we'll call the LOCI Bio-formats toolbox to convert anything into our
% favorit OME-TIFF format
function [newfile] = bftools_convert(fname)

  % We need the absolute path for Java to work properly
  fname = absolutepath(fname);

  if (exist(fname, 'file') ~= 2)
    error('Tracking:BadFile', ['File ' fname ' does not exist']);
  end

  % Split the filename
  [file_path, filename, ext] = fileparts(fname);

  % Remove the extension
  name = fullfile(file_path, filename);

  % Identify the filename VS the path
  [slash] = findstr(name, filesep);
  if(length(slash)>0)
    slash = slash(end) + 1;
  else
    slash = 1;
  end

  % Creat the fancy name for display (otherwise it thinks they are LaTeX commands)
  printname = strrep(name(slash:end),'_','\_');

  curdir = pwd;
  cmd_path = which('bfconvert.bat');
  if (isempty(cmd_path))
    error('Tracking:lociMissing', 'The LOCI command line tools are not present !\nPlease follow the instructions provided by install_cell_tracking');
  end
  [mypath, junk] = fileparts(cmd_path);

  hInfo = warndlg('Parsing metadata, please wait.', 'Converting movie...');

  cd(mypath);

  if (ispc)
    cmd_name = ['"' fname '"'];
    [res, metadata] = system(['showinf.bat -stitch -nopix -nometa ' cmd_name]);
  else
    cmd_name = strrep(fname,' ','\ ');
    [res, metadata] = system(['./showinf -stitch -nopix -nometa ' cmd_name]);
  end

  if (ishandle(hInfo))
    delete(hInfo);
  end

  if (res ~= 0)
    cd(curdir);
    error(metadata);
  end

  format = regexp(metadata, 'file format\s*\[([ -\w]+)\]', 'tokens');
  is_rgb = regexp(metadata, 'RGB\s*=\s*(\w+)', 'tokens');
  file_pattern = regexp(metadata, 'File pattern = (.*)\nUsed', 'tokens');

  % In case of multiple files, regroup them into one single file
  if (~isempty(file_pattern))
    file_pattern = regexprep(file_pattern{1}, '<\d+-\d+>', '');
  end

  % Something went terribly wrong...
  if (isempty(format) | isempty(is_rgb))
    cd(curdir);
    error('Tracking:lociFormat', ['The metadata does not present the expected information: ''file format'' and ''RGB'' :\n\n' metadata]);
  end

  format = format{1}{1};
  is_rgb = strncmp(is_rgb{1}{1}, 'true', 4);

  if (strncmpi(format,'OME-TIFF',8) && isempty(file_pattern))

    % If it's already an OME-TIFF file, we do not need to convert it, so stop here
    newfile = fname;
    cd(curdir);
    newfile = relativepath(newfile);

    return;
  end

  % RGB will not work
  if (is_rgb)
    warning('Tracking:RGB','RGB channels will be separated, please make sure that no information is lost !')
  end

  % We create an OME-TIFF file
  if (isempty(file_pattern))
    newname = [name '.ome.tiff'];
  else
    [file_path, file_name, file_ext] = fileparts(file_pattern{1});
    newname = fullfile(file_path, [file_name '.ome.tiff']);
  end

  % If the file already exists, we ask what to do
  if(exist(newname,'file'))

    % We initially do not know what to do
    answer = 0;

    % We do not accept "empty" answers
    while (answer == 0)
      answer = menu(['The OME-TIFF version of ' printname ' already exists, overwrite it ?'],'Yes','No');
    end

    % Act accorindly to the policy
    switch answer

      % Delete the current files (did not dare overwriting it directly)
      case 1
        delete(newname);

      % Otherwise we can stop here
      case 2
        % Store the new name
        newfile = newname;
        cd(curdir);
        newfile = relativepath(newfile);

        return;
    end
  end

  hInfo = warndlg('Converting to OME-TIFF, please wait.', 'Converting movie...');

  % Call directly the command line tool to do the job
  if (ispc)
    cmd_newname = ['"' newname '"'];
    [res, infos] = system(['bfconvert.bat -stitch -separate ' cmd_name ' ' cmd_newname]);
  else
    cmd_newname = strrep(newname,' ','\ ');
    [res, infos] = system(['./bfconvert -stitch -separate ' cmd_name ' ' cmd_newname]);
  end

  if (ishandle(hInfo))
    delete(hInfo);
  end

  if (res ~= 0)
    cd(curdir);
    error(infos);
  end

  % Store the new name in relative path and come back to the original folder
  newfile = newname;
  cd(curdir);
  newfile = relativepath(newfile);

  return;
end
