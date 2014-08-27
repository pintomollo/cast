function [mytracking, opts] = filter_paths(mytracking, opts)
% FILTER_PATHS filters the paths previously build by tracking the detections in the
% various channels of the experiment.
%
%   [MYTRACKING] = FILTER_PATHS(MYTRACKING, OPTS) filters the paths present in the
%   "trackings" field of MYTRACKING, using the options set in the "tracks_filtering"
%   structure.
%
%   [MYTRACKING, OPTS] = SEGMENT_MOVIE(...) also returns the option structure OPTS.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 28.08.2014

  % Get the number of channels to parse
  nchannels = length(mytracking.channels);

  % Loop over them
  for indx = 1:nchannels

    % Filter them
    mytracking.trackings(indx).detections = filter_tracking(mytracking.trackings(indx).detections, opts.tracks_filtering.min_path_length, opts.tracks_filtering.max_zip_length,opts.tracks_filtering.interpolate);

  end

  % And reestimate the spots if need be
  mytracking = reestimate_spots(mytracking, opts);

  return;
end
