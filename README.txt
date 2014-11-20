% README.txt
% A few expanations on how to use the Cell Tracking Plateform
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 20.11.2014
%
% contact: felix.naef@epfl.ch

Hi !

This set of functions (so-called Cell Tracking Plateform) are designed to provide
an intuitive user interface for the automated segmentation, tracking and
quantification of time-lapse fluorescence/luminescence data. All functions can
be accessed directly using command-lines, however it is designed to be used through
the main interface function "cell_tracking_GUI".

This program is distributed under the terms of the GNU GPL, please refer to
licence.txt for details.

% 0. Basics

 - This software has been developped and tested using Matlab 2012b and requires
   both a C/C++ compiler and the Image Processing Toolbox (tested using v. 8.1)

 - For install this plateform, please follow the instructions in INSTALL.txt

 - All functions have a corresponding help message that describes its function,
   inputs and outputs. Type "help myfunction" in the command line to read it.

 - Data are stored within Matlab using structures. This should be completely
   transparent to the user. However, if need be, their respective definitions
   can be found in cell-tracking/helpers/get_struct.m.

%
