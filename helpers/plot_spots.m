function hgroup = plot_spots(h, spots, color)

  if (nargin == 1)
    spots = h;
    h = gca;
    color = 'r';
  elseif (nargin == 2)
    if (ischar(spots))
      color = spots;
      spots = h;
      h = gca;
    end
  end

  if (iscell(spots))
    spots = spots{1};
  end

  spots = spots(all(~isnan(spots),2),:);

  if (strncmp(get(h, 'Type'), 'hggroup',7))
    hgroup = h;
  else
    hgroup = hggroup('Parent', h);
  end

  haxes = get(hgroup, 'Parent');

  status = get(haxes, 'NextPlot');
  set(haxes,'NextPlot', 'add');

  hrects = get(hgroup, 'Children');
  nrects = length(hrects);

  nspots = size(spots, 1);

  for i=1:nspots
    pos = [spots(i, 1:2)-2*spots(i,3) max(4*spots(i, [3 3]), [1 1])];

    if (i>nrects)
      rectangle('Position', pos, 'Curvature', [1 1], 'Parent', hgroup, 'EdgeColor', color);
    else
      set(hrects(i), 'Position', pos, 'EdgeColor', color);
    end
  end

  set(haxes,'NextPlot', status);

  delete(hrects(nspots+1:nrects))

  return;
end
