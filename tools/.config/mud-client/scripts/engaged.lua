local currently_engaged = 0

function engaged_increased()
  currently_engaged = currently_engaged + 1
  client.echo("Engaged increased to: " .. currently_engaged)
  client.var.set("current_engaged", currently_engaged)
end

function engaged_decreased()
  currently_engaged = currently_engaged - 1
  if currently_engaged < 0 then currently_engaged = 0 end
  client.echo("Engaged increased to: " .. currently_engaged)
  client.var.set("current_engaged", currently_engaged)
end

function reset_engaged()
  currently_engaged = 0
  client.echo("Engaged increased to: " .. currently_engaged)
  client.var.set("current_engaged", currently_engaged)
end
