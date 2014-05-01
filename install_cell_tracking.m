function install_cell_tracking
% INSTALL_CELL_TRACKING adds the required directories to the matlabpath
% and handles the directories structure and the dependent libraries.
%
% Naef labs, EPFL
% Simon Blanchoud
% 01.05.2014

  % Start by checking where we are, we need to be inside the cell_tracking folder
  current_dir = '';
  if (numel(dir('get_struct.m')) == 1)
    current_dir = pwd;
  else
    cd('cell-tracking');
    current_dir = pwd;
  end

  % Add the proper directories to MATLAB path
  addpath(current_dir);
  addpath(fullfile(current_dir, 'libraries'));
  addpath(fullfile(current_dir, 'helpers'));
  savepath;

  % Try to use the java libraries to see if they are properly installed
  if (exist('bfconvert.bat', 'file') ~= 2)
    if (exist('bftools', 'dir'))
      addpath(fullfile(current_dir, 'bftools'));
      savepath;

      if (~exist('bfconvert.bat', 'file'))
        error('ASSET:lociMissing', 'The LOCI command line tools are not present, this might be a problem if your recordings are not in TIFF format !\nYou can download them from http://downloads.openmicroscopy.org/latest/bio-formats5/\nThen place the entire folder in the cell-tracking folder.');
      end
    else
      error('ASSET:lociMissing', 'The LOCI command line tools are not present, this might be a problem if your recordings are not in TIFF format !\nYou can download them from http://downloads.openmicroscopy.org/latest/bio-formats5/\nThen place the entire folder in the cell-tracking folder.');
    end
  end

  cd ..;

  % This folder is required as well
  if (~exist('TmpData', 'dir'))
    mkdir('TmpData');
  end

  return;
end
