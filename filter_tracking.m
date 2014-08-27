function [spots, links] = filter_tracking(spots, links, min_path_length, max_zip_length, interpolate)
% FILTER_TRACKING corrects for potential confusions of the tracking algorithm by
% removing short tracks, fusing duplicated spots and interpolating missing detections.
%
%   [SPOTS, LINKS] = FILTER_TRACKING(SPOTS, LINKS) filters the SPOTS as well as the
%   LINKS connecting the SPOTS using the default values for each three operations
%   (see below).
%
%   [MYTRACKING] = FILTER_TRACKING(MYTRACKING) filters the segmentations of MYTRACKING.
%
%   [...] = FILTER_TRACKING(..., MIN_PATH_LENGTH) defines the minimal durations of a
%   track (in frames) for this track to be kept after filtering (default: 5).
%
%   [...] = FILTER_TRACKING(..., MIN_PATH_LENGTH, MAX_ZIP_LENGTH) defines in addition
%   the maximum number of frames to be "zipped" (default: 3). A track is defined as an
%   open "zipper" when a spot splits and these same tracks fuse back together. On short
%   time scales, this is characteristical of over-detections of the true signal.
%
%   [...] = FILTER_TRACKING(..., MIN_PATH_LENGTH, MAX_ZIP_LENGTH, INTERPOLATE) when
%   true, interpolates the position of missing detections (default: true). However,
%   the parameters of the corresponding interpolated spot are NOT interpolated. One
%   should reestimate them (see estimate_spots.m)
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 08.07.2014

  % Input checking
  if (nargin < 1)
    error('Tracking:filter_tracking', 'Not enough parameters provided (min=1)');
  elseif (nargin < 2)
    links = {};
    min_path_length = 5;
    max_zip_length = 3;
    interpolate = true;
  elseif (nargin < 3)
    min_path_length = 5;
    max_zip_length = 3;
    interpolate = true;
  elseif (nargin < 4)
    max_zip_length = 3;
    interpolate = true;
  elseif (nargin < 5)
    interpolate = true;
  end

  opts = [];
  if (isnumeric(links))

    if (islogical(min_path_length))
      interpolate = min_path_length;
    elseif (islogical(max_zip_length))
      interpolate = max_zip_length;
      max_zip_length = min_path_length;
    end

    min_path_length = links;
  elseif (isstruct(links))
    opts = links;
    min_path_length = opts.tracks_filtering.min_path_length;
    max_zip_length = opts.tracks_filtering.max_zip_length;
    interpolate = opts.tracks_filtering.interpolate;
  end

  mystruct = [];
  if (isstruct(spots))

    mystruct = spots;

    nframes = length(mystruct);
    spots = cell(nframes, 1);
    links = cell(nframes, 1);

    for i=1:nframes
      if (~all(isnan(mystruct(i).carth(:))))
        spots{i} = [mystruct(i).carth mystruct(i).properties];
        links{i} = mystruct(i).cluster;
      end
    end
  end

  nframes = length(spots);
  for i=1:nframes
    if (~isempty(spots{i}))
      nprops = size(spots{i},2)-2;
      break;
    end
  end

  if (min_path_length > 0)
    path_length = cell(nframes, 1);
    diff_indxs = cell(nframes, 1);

    for i=1:nframes
      curr_links = links{i};
      path_length{i} = zeros(size(spots{i}, 1), 1);
      for j=1:size(curr_links, 1)
        path_length{i}(curr_links(j,1)) = path_length{curr_links(j,3)}(curr_links(j,2)) + i - curr_links(j,3);
      end
    end
    for i=nframes:-1:1
      curr_links = links{i};

      curr_length = path_length{i};
      if (~isempty(curr_links))
        for j=1:size(curr_links, 1)
          path_length{curr_links(j,3)}(curr_links(j,2)) = curr_length(curr_links(j,1));
        end
      end

      long = (curr_length > min_path_length);
      good_indx = find(long);

      if any(good_indx)
        new_links = curr_links(ismember(curr_links(:,1), good_indx), :);

        mapping = [1:length(long)].' - cumsum(~long);
        new_links(:,1) = mapping(new_links(:,1));

        spots{i} = spots{i}(long, :);
        links{i} = new_links;
        diff_indxs{i} = mapping;
      else
        spots{i} = NaN(0,nprops+2);
        links{i} = NaN(0,3);
        diff_indxs{i} = [];
      end
    end
    for i=1:nframes
      curr_links = links{i};
      for j=1:size(curr_links, 1)
        curr_links(j, 2) = diff_indxs{curr_links(j,3)}(curr_links(j,2));
      end
      links{i} = curr_links;
    end
  end

  if (max_zip_length > 0)
    index_map = NaN(0,4);
    index_full = cell(0,1);
    zips = cell(0,1);
    for i=nframes:-1:1
      curr_links = links{i};
      nlinks = size(curr_links, 1);

      for j=1:nlinks
        link = curr_links(j,:);

        eqs = (curr_links(:,1) == link(1));
        does_split = any(eqs(j+1:end,1));

        refs = (index_map(:,3) == link(1,1) & index_map(:,4) == i);
        does_link = any(refs);

        if (does_split)
          splits = curr_links(eqs(:,1),:);
          splits = [splits(:,1) i*ones(size(splits,1),1) splits(:,2:3)];

          if (does_link)
            indxs = find(refs);

            for k=1:length(indxs)
              tmp_path = index_full{indxs(k)};
              for l=1:size(splits, 1)
                index_full{end+1} = [tmp_path;[tmp_path(end,1:2) splits(l,3:4)]];
              end
            end

            new_refs = false(length(index_full), 1);
            new_refs(1:length(refs)) = refs;

            index_full = index_full(~new_refs);
          else
            for k=1:size(splits, 1)
              index_full{end+1} = splits(k,:);
            end
          end
        elseif (does_link)
          indxs = find(refs);
          for k=1:length(indxs)
            tmp_path = index_full{indxs(k)};
            index_full{indxs(k)} = [tmp_path;[tmp_path(end,1:2) link(1,2:3)]];
          end
        end
      end

      index_map = cellfun(@(x)(x(end,:)), index_full, 'UniformOutput', false);
      index_map = cat(1, NaN(0,4), index_map{:});

      valid_maps = (index_map(:,2) <= i+max_zip_length & index_map(:,end) < i);
      index_map = index_map(valid_maps, :);
      index_full = index_full(valid_maps);

      [unique_map, indx1, indx2] = unique(index_map, 'rows');

      if (numel(unique_map) ~= numel(index_map))

        for k=1:length(indx1)
          if (sum(indx2==k) > 1)
            zips{end+1} = [index_full(indx2==k)];
          end
        end

        index_map = unique_map;
        index_full = index_full(indx1);
      end
    end

    tmp_props = NaN(1, nprops);
    del_spots = cell(nframes, 1);

    for i=1:length(zips)
      paths = zips{i};
      npaths = length(paths);

      max_frame = paths{1}(1,2);
      min_frame =  paths{1}(end, 4);
      frame_range = max_frame - min_frame + 1;

      all_pos = NaN([frame_range, 3, npaths]);
      for j=1:npaths
        curr_path = paths{j};

        all_pos(1,:,j) = [spots{curr_path(1,2)}(curr_path(1,1), 1:2) curr_path(1,2)];
        for k=1:size(curr_path,1)
          all_pos(max_frame - curr_path(k,end)+1,:,j) = [spots{curr_path(k,4)}(curr_path(k,3), 1:2) curr_path(k, 4)];
          if (curr_path(k,4) > min_frame)
            del_spots{curr_path(k,4)}(end+1) = curr_path(k,3);
          end
        end

        nans = isnan(all_pos(:,:,j));
        if (any(nans(:)))
          valids = ~any(nans, 2);
          frames = [max_frame:-1:min_frame].';
          all_pos(:,1:2,j) = interp1(all_pos(valids,3,j), all_pos(valids,1:2,j), frames);
          all_pos(:,3,j) = frames;
        end
      end

      avg_pos = mean(all_pos, 3);
      prev_indx = curr_path(1,1);

      for j=2:frame_range-1
        curr_frame = avg_pos(j, 3);
        spots{curr_frame}(end+1,:) = [avg_pos(j,1:2) tmp_props];
        new_indx = size(spots{curr_frame}, 1);

        links{curr_frame+1}(end+1,:) = [prev_indx new_indx curr_frame];
        prev_indx = new_indx;
      end
      links{min_frame+1}(end+1,:) = [prev_indx curr_path(end,3:4)];
    end

    diff_indxs = cell(nframes, 1);
    for i=nframes:-1:1
      curr_spots = [1:size(spots{i},1)].';
      rem_spots = ismember(curr_spots, del_spots{i});

      mapping = curr_spots - cumsum(rem_spots);
      mapping(rem_spots) = -1;

      spots{i} = spots{i}(~rem_spots, :);
      diff_indxs{i} = mapping;
    end
    for i=1:nframes
      curr_links = links{i};
      for j=1:size(curr_links, 1)
        curr_links(j, 1) = diff_indxs{i}(curr_links(j,1));
        curr_links(j, 2) = diff_indxs{curr_links(j,3)}(curr_links(j,2));
      end
      goods = all(curr_links > 0, 2);
      links{i} = curr_links(goods, :);
    end
  end

  if (interpolate)
    for i=nframes:-1:1
      curr_links = links{i};
      good_links = (curr_links(:,end)==i-1);
      links{i} = curr_links(good_links,:);
      curr_links = curr_links(~good_links,:);
      if (~isempty(curr_links))
        for j=1:size(curr_links, 1)
          curr_indxs = curr_links(j,:);
          target = spots{i}(curr_indxs(1),:);
          reference = spots{curr_indxs(3)}(curr_indxs(2),:);

          ninterp = i - curr_indxs(3);
          new_pts = bsxfun(@plus, bsxfun(@times, (reference(1:2) - target(1:2)) / ninterp, [1:ninterp-1].'), target(1:2));

          curr_pos = curr_indxs(1);
          for k=1:ninterp-1
            curr_indx = i-k;
            nprev = size(spots{curr_indx}, 1) + 1;
            spots{curr_indx} = [spots{curr_indx}; [new_pts(k,:) NaN(1,nprops)]];
            links{curr_indx+1} = [links{curr_indx+1}; [curr_pos nprev curr_indx]];
            curr_pos = nprev;
          end
          links{curr_indx} = [links{curr_indx}; [curr_pos, curr_indxs(2), curr_indx-1]];
        end
      end
    end
  end

  if (~isempty(mystruct))
    for i=1:nframes
      mystruct(i).carth = spots{i}(:,1:2);
      mystruct(i).properties = spots{i}(:,3:end);
      mystruct(i).cluster = links{i};
    end

    spots = mystruct;
    links = [];
  end

  return;
end
