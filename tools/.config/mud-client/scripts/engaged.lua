local currently_engaged = 0

function engaged_increased()
  currently_engaged = currently_engaged + 1
end

function engaged_decreased()
  currently_engaged = currently_engaged - 1
  if currently_engaged < 0 then currently_engaged = 0 end
end
