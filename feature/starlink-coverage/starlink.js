

var a = 2 * Math.PI * (5 / 8);
var b = 2 * Math.PI * (7 / 8);

// Thank you https://stackoverflow.com/questions/25042350/draw-a-pin-on-canvas-using-html5
function drawPin(ctx, pin) {
  ctx.save();
  ctx.translate(pin.x, pin.y);

  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.bezierCurveTo(2, -10, -20, -25, 0, -30);
  ctx.bezierCurveTo(20, -25, -2, -10, 0, 0);
  ctx.fillStyle = pin.color;
  ctx.fill();
  ctx.strokeStyle = "black";
  ctx.lineWidth = 1.5;
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(0, -21, 3, 0, Math.PI * 2);
  ctx.closePath();
  ctx.fillStyle = "black";
  ctx.fill();

  ctx.restore();
}

let angle = document.getElementById("angle");
let angle_text = document.getElementById("angle_text");
angle.oninput = _ => angle_text.textContent = angle.value + "°";
angle.value = 25;

let autorotate_elem = document.getElementById("autorotate");
autorotate_elem.checked = true;
autorotate_elem.onclick = _ => planet.plugins.autorotate.set_paused(!autorotate_elem.checked);

let menu_active = false;
let menu_toggle = document.getElementById("menu_toggle");

menu_toggle.onclick = e => {
  menu_active = !menu_active;

  menu_active ? display_menu() : hide_menu();
}

function display_menu() {
  const style = document.documentElement.style
  style.setProperty("--menu-open", "block");
}

function hide_menu() {
  const style = document.documentElement.style
  style.setProperty("--menu-open", "none");
}

function display_help() {
  const style = document.documentElement.style
  style.setProperty("--explanation", "inline-block");
  style.setProperty("--help", "none");
}

function hide_help() {
  const style = document.documentElement.style
  style.setProperty("--explanation", "none");
  style.setProperty("--help", "inline-block");
}

let rot_speed = document.getElementById("rot_speed");

let circle_color = document.getElementById("circle_color");
let highlight_color = document.getElementById("highlight_color");
let highlight_enabled = document.getElementById("highlight_enabled");
let sat_color = document.getElementById("sat_color");
let sat_enabled = document.getElementById("sat_enabled");
let land_color = document.getElementById("land_color");
let ocean_color = document.getElementById("ocean_color");
let nation_color = document.getElementById("nation_color");
let nation_enabled = document.getElementById("nation_enabled");
let edge_color = document.getElementById("edge_color");
let edge_enabled = document.getElementById("edge_enabled");

let earth_settings = {
  topojson: {
    file: 'world-110m.json'
  },
  oceans: {
    fill: '#203340'
  },
  land: {
    fill: '#645817',
    stroke: "#8093a0"
  },
  borders: {
    stroke: '#a043a0'
  }
}

land_color.oninput = _ => earth_settings.land.fill = land_color.value;
ocean_color.oninput = _ => earth_settings.oceans.fill = ocean_color.value;
let nation_update = _ => earth_settings.borders.stroke = nation_enabled.checked ? nation_color.value : land_color.value;
nation_color.oninput = nation_update;
nation_enabled.oninput = nation_update;
let edge_update = _ => earth_settings.land.stroke = edge_enabled.checked ? edge_color.value : false;
edge_color.oninput = edge_update;
edge_enabled.oninput = edge_update;

let addresses = document.getElementById("addresses");
var geocoder; // Initialized when gmaps loads
var pin_locations = [];

function new_address() {
  let i = addresses.childElementCount;
  let node = document.createElement("input");
  node.type = "search";
  node.onchange = _ => update_address(i, node.value);
  node.style = "width:100%;display:block;";
  node.placeholder = "Pin Address";
  addresses.appendChild(node);
  pin_locations.push(false);
}

// Initial address
new_address();

function update_address(i, address) {
  if (address == "") {
    planet.requiresRedraw = true;
    pin_locations[i] = false;
    for (let i = addresses.childElementCount - 1; i > 0; i--) {
      if (addresses.children[i - 1].value != "") {
        break;
      }

      pin_locations.pop();
      addresses.lastChild.remove();
    }

    return;
  }

  if (i + 1 == addresses.childElementCount) {
    // Add an blank address if this is the last address
    new_address();
  }

  pin_address(i, address);
}

let frametime_el = document.getElementById("frametime");
let realtime = document.getElementById("realtime");
let speed_in = document.getElementById("speed");
let speed_out = document.getElementById("speed_out");

// Time at which we are simulating from
let base_time = new Date().getTime();
// Realtime that we last base_time
let reference_time = base_time;
// Controls framerate
let framedelay = 1 / 6;
// Playback speed
let speed = 1;

function update_timing(self) {
  if (self.target !== realtime) {
    realtime.checked = false;
  }

  let speed_parsed = Math.round(parseFloat(speed_in.value) ** 2)
  speed_out.textContent = speed_parsed + "x";

  if (realtime.checked) {
    base_time = new Date().getTime();
    reference_time = base_time;

    framedelay = 1 / 6;
    speed = 1;
  } else {
    let new_time = new Date().getTime();
    base_time += (new_time - reference_time) * speed;
    reference_time = new_time;

    speed = speed_parsed;
    framedelay = Math.max(1 / 60, speed / 6);
  }
}

frametime_el.oninput = update_timing;
realtime.oninput = update_timing;
speed_in.oninput = update_timing;

update_timing({
  target: realtime
});

satellite_positions = [];

function periodic_regen_positions() {
  d3.timer(_ => periodic_regen_positions(), 1 / 6);

  let render_time;
  if (realtime.checked) {
    render_time = new Date();
  } else {
    render_time = base_time + (new Date().getTime() - reference_time) * speed;
    render_time = new Date(render_time);
  }

  frametime_el.textContent = render_time.toUTCString();

  planet.requiresRedraw = true;
  satellite_positions = generate_positions(render_time);
  return true
}

function pin_address(i, address) {
  geocoder.geocode({
    'address': address
  }, function(results, status) {
    if (status === 'OK') {
      planet.requiresRedraw = true;
      let l = results[0].geometry.location;
      pin_locations[i] = [l.lng(), l.lat()];
    } else {
      alert('Geocode was not successful for the following reason: ' + status);
    }
  })
}

Math.radians = function(degrees) {
  return degrees / 180 * Math.PI;
};

Math.degrees = function(radians) {
  return radians * 180 / Math.PI;
};

// Plugin to resize the canvas to fill the window and to
// automatically center the planet when the window size changes
function autocenter(options) {
  options = options || {};
  var needsCentering = false;
  var globe = null;

  var resize = function() {
    var width = container.offsetWidth + (options.extraWidth || 0);
    var height = container.offsetHeight + (options.extraHeight || 0);
    globe.canvas.width = width;
    globe.canvas.height = height;
    globe.projection.translate([width / 2, height / 2]);
  };

  return function(planet) {
    globe = planet;
    planet.onInit(function() {
      needsCentering = true;
      d3.select(window).on('resize', function() {
        needsCentering = true;
      });
    });

    planet.onDraw(function() {
      if (needsCentering) {
        resize();
        needsCentering = false;
      }
    });
  };
};

// Plugin to automatically scale the planet's projection based
// on the window size when the planet is initialized
function autoscale(options) {
  options = options || {};
  return function(planet) {
    planet.onInit(function() {
      var width = container.offsetWidth + (options.extraWidth || 0);
      var height = container.offsetHeight + (options.extraHeight || 0);
      planet.projection.scale(Math.min(width, height) / 2);
    });
  };
};

// Plugin to automatically rotate the globe around its vertical
// axis a configured number of degrees every second.
function autorotate(degPerSecFunc) {
  return function(planet) {
    var lastTick = null;
    var paused = false;
    var manually_paused = false;
    planet.plugins.autorotate = {
      set_paused: function(v) {
        manually_paused = v;
      },
      pause: function() {
        paused = true;
      },
      resume: function() {
        paused = false;
      }
    };
    planet.onDraw(function() {
      if (paused || manually_paused || !lastTick) {
        lastTick = new Date();
      } else {
        planet.requiresDredraw = true;
        var now = new Date();
        var delta = now - lastTick;
        var rotation = planet.projection.rotate();
        rotation[0] += degPerSecFunc() * delta / 1000;
        if (rotation[0] >= 180) rotation[0] -= 360;
        planet.projection.rotate(rotation);
        lastTick = now;
      }
    });
  };
};

let canvas = document.getElementById("globe");
let container = document.getElementById("starlink-coverage");

var planet = planetaryjs.planet();
planet.loadPlugin(autocenter({
  extraHeight: 0
}));
planet.loadPlugin(autoscale({
  extraHeight: -40
}));
planet.loadPlugin(planetaryjs.plugins.earth(earth_settings));
planet.loadPlugin(planetaryjs.plugins.pings());
planet.loadPlugin(planetaryjs.plugins.zoom({
  scaleExtent: [50, 5000]
}));
planet.loadPlugin(planetaryjs.plugins.drag({
  onDragStart: function() {
    this.plugins.autorotate.pause();
  },
  onDragEnd: function() {
    this.plugins.autorotate.resume();
  },
  afterDrag: function() {
    planet.requiresRedraw = true;
  }
}));
planet.loadPlugin(autorotate(_ => parseFloat(rot_speed.value) ** 2));
planet.projection.rotate([100, -10, 0]);
planet.draw(canvas);
planet.requiresRedraw = true;

// Defined out here so that you can play with it in the console
var satellites = [];
var satellite_positions;

function generate_positions(time) {
  var gmst = satellite.gstime(time);
  var positions = satellites.map(sat => {

    let pos_and_vel = satellite.propagate(sat, time);
    if(sat.error != 0) { return; }

    let pos_gd = satellite.eciToGeodetic(pos_and_vel.position, gmst);
    let lng = pos_gd.longitude * 180 / Math.PI;
    let lat = pos_gd.latitude * 180 / Math.PI;

    let orbit_radius = pos_gd.height + 6371;
    let angle_horizon_station_satellite = parseFloat(angle.value);
    let angle_earth_station_satellite = 90 + angle_horizon_station_satellite;
    let angle_station_satellite_earth = Math.degrees(Math.asin(
      Math.sin(Math.radians(angle_earth_station_satellite)) * 6371 / orbit_radius));
    let angle_satellite_earth_observer = 180 - angle_earth_station_satellite - angle_station_satellite_earth;

    return [lng, lat, pos_gd.height + 6371, angle_satellite_earth_observer];
  });

  return positions.filter( pos => { return pos !== undefined; });
}

fetch("starlink-data.txt")
  .then(r => r.text(), _ => console.log("starlink data failed"))
  .then(text => {
    rows = text.split(/\r?\n/);
    for (let i = 0; i + 2 < rows.length; i += 3) {
      satellites.push(satellite.twoline2satrec(rows[i + 1], rows[i + 2]));
    }

    periodic_regen_positions();

    planet.onDraw(_ => {
      let rotation = planet.projection.rotate();
      rotation[0] *= -1;
      rotation[1] *= -1;

      satellite_positions.forEach(pos => {
        let lng = pos[0];
        let lat = pos[1];
        let height = pos[2];
        let angular_size = pos[3];
        // Only draw cirlces on the same side of the planet
        if (d3.geo.distance(rotation, [lng, lat]) > Math.PI / 2) {
          return;
        }
        // if( lng > 185 || lng < 175 ) { return }

        let circle = d3.geo.circle().origin([lng, lat]).angle(angular_size)();

        if (highlight_enabled.checked &&
          pin_locations.some(loc => loc) &&
          pin_locations.every(loc =>
            loc == false || Math.degrees(d3.geo.distance(loc, [lng, lat])) < angular_size
          )) {
          planet.context.fillStyle = highlight_color.value;
        } else {
          planet.context.fillStyle = circle_color.value;
        }

        planet.context.globalAlpha = 0.2
        planet.context.beginPath();
        planet.path.context(planet.context)(circle);
        planet.context.fill();
        planet.context.globalAlpha = 1

        if (sat_enabled.checked) {
          planet.context.fillStyle = sat_color.value;
          let scale = planet.projection.scale();
          let new_scale = scale * (height / 6371);
          planet.projection.scale(new_scale)
          let xy = planet.projection([lng, lat]);
          planet.context.beginPath();
          planet.context.arc(xy[0], xy[1], 1, 0, 2 * Math.PI);
          planet.context.fill();
          planet.projection.scale(scale)
        }
      });

      pin_locations.forEach(pin_location => {
        if (pin_location != false && d3.geo.distance(rotation, pin_location) <= Math.PI / 2) {
          let xy = planet.projection(pin_location)
          drawPin(planet.context, {
            x: xy[0],
            y: xy[1],
            color: "#aa6688",
          });
        }
      });
    })
  }, _ => console.log("get starlink data text failed"))

function init_gmaps() {
  geocoder = new google.maps.Geocoder();
}

hide_help();
hide_menu();
