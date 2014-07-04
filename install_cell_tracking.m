function install_cell_tracking
% INSTALL_CELL_TRACKING adds the required directories to the matlabpath
% and handles the directories structure and the dependent libraries. It also
% compiles the required MEX libraries, hence a C/C++ compiler is requried.
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

  % Check if the Bio-formats toolbox is properly installed
  if (exist('bfconvert.bat', 'file') ~= 2)
    if (exist('bftools', 'dir'))
      addpath(fullfile(current_dir, 'bftools'));
      savepath;

      if (~exist('bfconvert.bat', 'file'))
        cd ..;
        error('Tracking:lociMissing', 'The LOCI command line tools are not present, this might be a problem if your recordings are not in TIFF format !\nYou can download them from http://downloads.openmicroscopy.org/latest/bio-formats5/\nThen place the entire folder in the cell-tracking folder.');
      end
    else
      cd ..;
      error('Tracking:lociMissing', 'The LOCI command line tools are not present, this might be a problem if your recordings are not in TIFF format !\nYou can download them from http://downloads.openmicroscopy.org/latest/bio-formats5/\nThen place the entire folder in the cell-tracking folder.');
    end
  end

  % Check if the sparse 64bits flag is needed
  if ~isempty(strfind(computer(),'64'))
    mexopts = ' -largeArrayDims';
  else
    mexopts = '';
  end

  % Ask for the configuration only once
  did_setup = false;

  % Try to compile the necessary MEX files
  if (exist('median_mex') ~= 3)
    try
      if (~did_setup)
        mex -setup;
      end
      eval(['mex MEX' filesep 'median_mex.c']);
      did_setup = true;
    catch ME
      cd ..;
      error('Tracking:MEX', ['Could not compile the required MEX function!\n' ME.message]);
    end
  end
  if (exist('gaussian_mex') ~= 3)
    try
      if (~did_setup)
        mex -setup;
      end
      eval(['mex MEX' filesep 'gaussian_mex.c']);
      did_setup = true;
    catch ME
      cd ..;
      error('Tracking:MEX', ['Could not compile the required MEX function!\n' ME.message]);
    end
  end
  if (exist('nl_means_mex') ~= 3)
    try
      if (~did_setup)
        mex -setup;
      end
      eval(['mex MEX' filesep 'nl_means_mex.cpp']);
      did_setup = true;
    catch ME
      cd ..;
      error('Tracking:MEX', ['Could not compile the required MEX function!\n' ME.message]);
    end
  end
  if (exist('bilinear_mex') ~= 3)
    try
      if (~did_setup)
        mex -setup;
      end
      eval(['mex MEX' filesep 'bilinear_mex.c']);
      did_setup = true;
    catch ME
      cd ..;
      error('Tracking:MEX', ['Could not compile the required MEX function!\n' ME.message]);
    end
  end
  if (exist('get_sparse_data_mex') ~= 3)
    try
      if (~did_setup)
        mex -setup;
      end
      eval(['mex' mexopts ' MEX' filesep 'get_sparse_data_mex.c']);
      did_setup = true;
    catch ME
      cd ..;
      error('Tracking:MEX', ['Could not compile the required MEX function!\n' ME.message]);
    end
  end
  if (exist('linking_cost_sparse_mex') ~= 3)
    try
      if (~did_setup)
        mex -setup;
      end
      eval(['mex' mexopts ' MEX' filesep 'linking_cost_sparse_mex.c']);
      did_setup = true;
    catch ME
      cd ..;
      error('Tracking:MEX', ['Could not compile the required MEX function!\n' ME.message]);
    end
  end
  if (exist('bridging_cost_sparse_mex') ~= 3)
    try
      if (~did_setup)
        mex -setup;
      end
      eval(['mex' mexopts ' MEX' filesep 'bridging_cost_sparse_mex.c']);
      did_setup = true;
    catch ME
      cd ..;
      error('Tracking:MEX', ['Could not compile the required MEX function!\n' ME.message]);
    end
  end  if (exist('joining_cost_sparse_mex') ~= 3)
    try
      if (~did_setup)
        mex -setup;
      end
      eval(['mex' mexopts ' MEX' filesep 'joining_cost_sparse_mex.c']);
      did_setup = true;
    catch ME
      cd ..;
      error('Tracking:MEX', ['Could not compile the required MEX function!\n' ME.message]);
    end
  end
  if (exist('splitting_cost_sparse_mex') ~= 3)
    try
      if (~did_setup)
        mex -setup;
      end
      eval(['mex' mexopts ' MEX' filesep 'splitting_cost_sparse_mex.c']);
      did_setup = true;
    catch ME
      cd ..;
      error('Tracking:MEX', ['Could not compile the required MEX function!\n' ME.message]);
    end
  end
  cd ..;

  % This folder is required as well
  if (~exist('TmpData', 'dir'))
    mkdir('TmpData');
  end

  return;
end
