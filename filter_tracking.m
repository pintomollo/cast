function [spots, links] = filter_tracking(spots, links, min_path_length, interpolate)

  % Input checking
  if (nargin < 1)
    error('Tracking:filter_tracking', 'Not enough parameters provided (min=1)');
  elseif (nargin < 2)
    links = {};
    min_path_length = 5;
    interpolate = true;
  elseif (nargin < 3)
    min_path_length = 5;
    interpolate = true;
  elseif (nargin < 4)
    interpolate = true;
  end

  mystruct = [];
  if (isstruct(spots))
    if (islogical(min_path_length))
      interpolate = min_path_length;
    end
    if (isnumeric(links))
      min_path_length = links;
    end

    mystruct = spots;

    nframes = length(mystruct);
    spots = cell(nframes, 1);
    links = cell(nframes, 1);

    for i=1:nframes
      spots{i} = [mystruct(i).carth mystruct(i).properties];
      links{i} = mystruct(i).cluster;
    end
  end

  nframes = length(spots);

  if (min_path_length > 0)
    path_length = cell(nframes, 1);
    diff_indxs = cell(nframes, 1);

    for i=1:nframes
      nimg = i;

      curr_links = links{nimg};
      path_length{nimg} = zeros(size(spots{nimg}, 1), 1);
      for j=1:size(curr_links, 1)
        path_length{nimg}(curr_links(j,1)) = path_length{curr_links(j,3)}(curr_links(j,2)) + nimg - curr_links(j,3);
      end
    end
    for i=nframes:-1:1
      nimg = i;

      curr_links = links{nimg};
      curr_length = path_length{nimg};
      if (~isempty(curr_links))
        for j=1:size(curr_links, 1)
          path_length{curr_links(j,3)}(curr_links(j,2)) = curr_length(curr_links(j,1));
        end
      end

      long = (curr_length > min_path_length);
      good_indx = find(long);
      new_links = curr_links(ismember(curr_links(:,1), good_indx), :);

      %bad_indx = find(~long);
      %spots{nimg}(~long, :) = NaN;
      %bad_prev = curr_links(ismember(curr_links(:,1), bad_indx), 2:3);
      mapping = [1:length(long)].' - cumsum(~long);
      new_links(:,1) = mapping(new_links(:,1));

      spots{nimg} = spots{nimg}(long, :);
      links{nimg} = new_links;
      diff_indxs{nimg} = mapping;

      %if (~isempty(bad_prev))
      %  prev_frames = unique(bad_prev(:, 2)).';

      %  for p=prev_frames
          %interpolated = isnan(spots{nimg-1}(bad_prev, end));
          %spots{nimg-1}(bad_prev(interpolated), :) = NaN;
      %    curr_prev = bad_prev(bad_prev(:,2)==p,1);
      %    spots{p}(curr_prev, :) = NaN;
      %  end
      %end
    end
    for i=1:nframes
      nimg = i;

      curr_links = links{nimg};
      for j=1:size(curr_links, 1)
        curr_links(j, 2) = diff_indxs{curr_links(j,3)}(curr_links(j,2));
      end
      links{nimg} = curr_links;
    end
  end

  if (interpolate)

    for i=1:nframes
      if (~isempty(spots{i}))
        nprops = size(spots{i},2)-2;
        break;
      end
    end

    for i=nframes:-1:1
      nimg = i;

      curr_links = links{nimg};
      good_links = (curr_links(:,end)==nimg-1);
      links{nimg} = curr_links(good_links,:);
      curr_links = curr_links(~good_links,:);
      if (~isempty(curr_links))
        for j=1:size(curr_links, 1)
          curr_indxs = curr_links(j,:);
          target = spots{nimg}(curr_indxs(1),:);
          reference = spots{curr_indxs(3)}(curr_indxs(2),:);

          ninterp = nimg - curr_indxs(3);
          new_pts = bsxfun(@plus, bsxfun(@times, (reference(1:2) - target(1:2)) / ninterp, [1:ninterp-1].'), target(1:2));

          curr_pos = curr_indxs(1);
          for k=1:ninterp-1
            curr_indx = nimg-k;
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
