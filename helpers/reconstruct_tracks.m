function paths = reconstruct_tracks(spots, links)

  if (isstruct(spots))
    mystruct = spots;
    nframes = length(mystruct);

    spots = cell(nframes, 1);
    links = cell(nframes, 1);

    for i=1:nframes
      spots{i} = [mystruct(i).carth mystruct(i).properties];
      links{i} = mystruct(i).cluster;
    end
  end

  hwait = waitbar(0,'','Name','Cell Tracking');
  waitbar(0, hwait, ['Reconstructing tracks...']);

  nframes = length(spots);
  indxs = NaN(0,3);
  paths = {};

  for i=nframes:-1:1
    curr_spots = spots{i};

    curr_link = links{i};

    nspots = size(curr_spots, 1);

    for j=1:nspots
      curr_indxs = indxs;
      indx = find(curr_indxs(:,1)==j & curr_indxs(:,2)==i);

      if (isempty(curr_link))
        link = [];
      else
        link = curr_link(curr_link(:,1)==j,2:end);
      end
      nlinks = size(link, 1);

      status = -(nlinks > 1);

      if (~isempty(indx))
        division = any(curr_indxs(indx,3));
        if (division)
          status = division;
        end
        for k=1:length(indx)
          paths{indx(k)} = [paths{indx(k)}; [status curr_spots(j,:) i]];
        end
      else
        paths{end+1} = [status curr_spots(j,:) i];
        indx = length(paths);
      end

      for l=1:length(indx)
        if (nlinks == 0)
          indxs(indx(l),:) = [j -1 0];
        else
          found = any(curr_indxs(:,1)==link(1) & curr_indxs(:,2)==link(2));

          indxs(indx(l),:) = [link(1,:) found];
          for k=2:nlinks
            paths{indx(l)}(end, 1) = -1;
            paths{end+1} = paths{indx(l)};
            indxs(end+1,:) = [link(k,:) found];
          end
        end
      end
    end

    waitbar((nframes-i+1)/nframes,hwait);
  end

  close(hwait);

  return;
end
