function [myrecording, opts] = filter_paths(myrecording, opts)
% FILTER_PATHS filters the paths previously build by tracking the detections in the
% various channels of the experiment, reestimating theire parameters if need be.
%
%   [MYRECORDING] = FILTER_PATHS(MYRECORDING, OPTS) filters the paths present in the
%   "trackings" field of MYRECORDING, using the options set in the "tracks_filtering"
%   structure.
%
%   [MYRECORDING, OPTS] = FILTER_PATHS(...) also returns the option structure OPTS.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 28.08.2014

  % Get the number of channels to parse
  nchannels = length(myrecording.channels);

  % Loop over them
  for indx = 1:nchannels

    % Filter them
    myrecording.trackings(indx).filtered = filter_tracking(myrecording.trackings(indx).detections, opts.tracks_filtering.min_path_length, opts.tracks_filtering.max_zip_length,opts.tracks_filtering.interpolate);

  end

  % And reestimate the spots if need be
  myrecording = reestimate_spots(myrecording, opts);

  return;
end
