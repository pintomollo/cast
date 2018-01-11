function  abs_path = absolutepath( rel_path, act_path, throwErrorIfFileNotExist )
%ABSOLUTEPATH  returns the absolute path relative to a given startpath.
%   The startpath is optional, if omitted the current dir is used instead.
%   Both argument must be strings.
%
%   Syntax:
%      abs_path = ABSOLUTEPATH( rel_path, start_path )
%
%   Parameters:
%      rel_path           - Relative path
%      start_path         - Start for relative path  (optional, default = current dir)
%
%   Examples:
%      absolutepath( '.\data\matlab'        , 'C:\local' ) = 'c:\local\data\matlab\'
%      absolutepath( 'A:\MyProject\'        , 'C:\local' ) = 'a:\myproject\'
%
%      absolutepath( '.\data\matlab'        , cd         ) is the same as
%      absolutepath( '.\data\matlab'                     )
%
%   See also:  RELATIVEPATH PATH

%   Jochen Lenz

%   Jonathan karr 12/17/2010
%   - making compatible with linux
%   - commented out lower cases
%   - switching findstr to strfind
%   - fixing mlint warnings
%   Jonathan karr 1/11/2011
%   - Per Abel Brown's comments adding optional error checking for absolute path of directories that don't exist
%   Jonathan karr 1/12/2011
%   - fixing bugs and writing test

%   Simon Blanchoud 11/20/2014
%   - Modified to accept already absolute paths
%   - Allowed non-existing absolute paths

% 2nd parameter is optional:
if nargin < 3
    throwErrorIfFileNotExist = false;
    if  nargin < 2
        act_path = pwd;
    end
end

%build absolute path
file = java.io.File(rel_path);
if (file.isAbsolute())
    abs_path = rel_path;
else
    file = java.io.File([act_path filesep rel_path]);
    abs_path = char(file.getCanonicalPath());
end

%check that file exists
if throwErrorIfFileNotExist && ~exist(abs_path, 'file')
    throw(MException('absolutepath:fileNotExist', 'The path %s or file %s doesn''t exist', abs_path, abs_path(1:end-1)));
end
