// Voronoi Sphere
// Hollow sphere with a flat bottom, a Voronoi cut-out pattern and a
// twist-lock (bayonet) cap in the base for filling it.
// Tip: use OpenSCAD 2024+ with the Manifold backend
// (Preferences > Advanced > 3D Rendering: Manifold) for fast renders.
//
// Using the cap: line the cap's lugs up with the slots in the opening,
// push it in until it is flush with the base, then twist it to lock.

/* [Output] */
part = "both"; // [both, body, cap, assembled]

/* [Color] */
print_color = "#EFE6D2"; // beige / off-white

/* [Size] */
diameter = 80;  // outer diameter (mm)
wall     = 2;   // shell thickness (mm)
flat_cut = 12;  // how much is sliced off the bottom (mm)

/* [Voronoi] */
hole_size    = 7;    // typical hole width, flat side to flat side (mm)
open_ratio   = 0.68; // fraction of the surface that is open
corner_ratio = 0.18; // corner rounding as a fraction of hole_size; 0 = sharp
jitter       = 0.6;  // 0 = regular honeycomb-ish, 1 = very irregular
solid_band   = 6;    // height of solid wall kept above the flat base (mm)
seed         = 42;   // change for a different random pattern

/* [Cap] */
opening       = 40;  // diameter of the fill opening (mm)
collar_wall   = 3;   // wall of the collar that holds the bayonet slots (mm)
collar_height = 16;  // height of the collar inside the sphere (mm)
floor_ring    = 2;   // thickness of the base ring around the opening (mm)
cap_plate     = 5;   // thickness of the cap's bottom plate (mm)
cap_wall      = 2;   // wall of the cap's plug ring (mm)
grip_depth    = 3;   // depth of the finger pocket under the cap (mm)
grip_bar      = 6;   // width of the bar you twist in the finger pocket (mm)
lug_count     = 3;
lug_width     = 8;   // along the circumference (mm)
lug_height    = 3;
lug_depth     = 1.2; // how far the lugs stick out (mm)
lock_angle    = 40;  // twist needed to lock (degrees)
detent        = 0.3; // click bump at the locked position (mm); 0 = none
clearance     = 0.3; // fit gap between cap and body (mm)

/* [Quality] */
$fn = 96;
round_fn = 24;     // smoothness of the rounded hole corners

// ---------------------------------------------------------------

R   = diameter / 2;
zc  = R - flat_cut;        // sphere centre height above the base
big = 2 * R + 10;

// Derive the cell count and strut width from the hole size and open ratio,
// treating the cells as hexagons on the outer surface.
cell_width    = hole_size / sqrt(open_ratio);
strut         = cell_width - hole_size;
cells         = round(4 * PI * R * R / (sqrt(3) / 2 * cell_width * cell_width));
corner_radius = corner_ratio * hole_size;

echo(str("cells = ", cells, ", strut = ", strut, " mm"));
if (strut < 1.2)
    echo("WARNING: struts are under 1.2 mm; lower open_ratio or raise hole_size");

// Bayonet geometry
r_hole  = opening / 2;
r_plug  = r_hole - clearance;           // cap plug outer radius
r_slot  = r_hole + lug_depth;           // back wall of the slots
lug_ang = lug_width / r_hole * 180 / PI;
gap_ang = 2 * clearance / r_hole * 180 / PI;
run_top = collar_height - 2.2;          // ceiling of the locking slot
lug_top = run_top - clearance;
lug_bot = lug_top - lug_height;
run_bot = lug_bot - clearance;

r_inner_base = sqrt(pow(R - wall, 2) - zc * zc);
assert(r_hole + collar_wall < r_inner_base - 1,
       "opening + collar is too wide for the sphere's base");
assert(lock_angle > lug_ang + 5, "lock_angle is too small for the lug width");

function unit(v) = v / norm(v);

// Seed points: Fibonacci sphere + random jitter, projected back onto the unit sphere.
golden  = 180 * (3 - sqrt(5));     // golden angle in degrees
spacing = sqrt(4 * PI / cells);    // approx. distance between neighbours
rnd     = rands(-1, 1, cells * 3, seed);

pts = [for (i = [0 : cells - 1])
    let(z = 1 - 2 * (i + 0.5) / cells,
        r = sqrt(1 - z * z),
        a = golden * i)
    unit([r * cos(a), r * sin(a), z]
         + jitter * 0.5 * spacing * [rnd[3*i], rnd[3*i+1], rnd[3*i+2]])];

// Only nearby points can share a cell border.
nb_dist = 2.6 * spacing;
function neighbours(i) =
    [for (j = [0 : cells - 1]) if (j != i && norm(pts[j] - pts[i]) < nb_dist) j];

// Half-space { x : x . n <= d }
module halfspace(n, d) {
    rotate([0, acos(n.z), atan2(n.y, n.x)])
        translate([-big / 2, -big / 2, d - big]) cube(big);
}

// Spherical Voronoi cell i as a cone from the centre. Seeds lie on the unit
// sphere, so each bisector plane passes through the origin; shifting it by
// strut/2 leaves constant-width struts through the whole wall.
// For rounding, the cell is shrunk by corner_radius and grown back with a
// sphere, which rounds every corner while keeping the strut width.
module cell_hole(i) {
    if (corner_radius > 0)
        minkowski() {
            cell_core(i, strut / 2 + corner_radius);
            sphere(r = corner_radius, $fn = round_fn);
        }
    else
        cell_core(i, strut / 2);
}

module cell_core(i, inset) {
    intersection_for(j = neighbours(i))
        halfspace(unit(pts[j] - pts[i]), -inset);
}

// Ring segment between angles a0..a1, radii r0..r1, heights z0..z1.
module arc_block(a0, a1, r0, r1, z0, z1) {
    rotate([0, 0, a0]) translate([0, 0, z0])
        rotate_extrude(angle = a1 - a0)
            translate([r0, 0]) square([r1 - r0, z1 - z0]);
}

module above_base() {
    translate([-big / 2, -big / 2, 0]) cube(big);
}

module shell() {
    intersection() {
        translate([0, 0, zc]) difference() {
            sphere(r = R);
            sphere(r = R - wall);
        }
        above_base();
    }
}

module holes() {
    intersection() {
        translate([0, 0, zc]) {
            union() for (i = [0 : cells - 1]) cell_hole(i);
        }
        translate([0, 0, zc]) sphere(r = R + 1);
        // keep a solid band above the base for bed adhesion
        translate([-big / 2, -big / 2, solid_band]) cube(big);
    }
}

// L-shaped slots: straight up from the base, then around by lock_angle.
module bayonet_slots() {
    for (k = [0 : lug_count - 1]) rotate([0, 0, k * 360 / lug_count]) {
        arc_block(-lug_ang / 2 - gap_ang, lug_ang / 2 + gap_ang,
                  r_hole - 1, r_slot, -1, run_top);
        arc_block(-lug_ang / 2 - gap_ang, lock_angle + lug_ang / 2 + gap_ang,
                  r_hole - 1, r_slot, run_bot, run_top);
    }
}

// Small rounded ridges the lugs click over just before the locked position.
module detents() {
    if (detent > 0)
        for (k = [0 : lug_count - 1])
            rotate([0, 0, k * 360 / lug_count + lock_angle - lug_ang / 2 - 3])
                intersection() {
                    translate([r_slot + 0.8 - clearance - detent, 0, run_bot])
                        cylinder(r = 0.8, h = run_top - run_bot, $fn = 24);
                    cylinder(r = r_slot + 0.1, h = big);
                }
}

module body() {
    difference() {
        union() {
            difference() {
                shell();
                holes();
            }
            // base ring joining the collar to the shell
            intersection() {
                translate([0, 0, zc]) sphere(r = R);
                cylinder(r = big, h = floor_ring);
            }
            cylinder(r = r_hole + collar_wall, h = collar_height);
        }
        translate([0, 0, -1]) cylinder(r = r_hole, h = collar_height + 2);
        bayonet_slots();
    }
    detents();
}

// Printed plate-down, as modelled.
module cap() {
    grip_d = 2 * r_plug - 8;
    difference() {
        union() {
            cylinder(r = r_plug, h = collar_height - 0.5);
            for (k = [0 : lug_count - 1]) rotate([0, 0, k * 360 / lug_count])
                arc_block(-lug_ang / 2, lug_ang / 2,
                          r_plug - 0.5, r_plug + lug_depth, lug_bot, lug_top);
        }
        // open cup above the plate
        translate([0, 0, cap_plate]) cylinder(r = r_plug - cap_wall, h = big);
        // finger pocket with a bar across it, so the base stays flat
        difference() {
            translate([0, 0, -1]) cylinder(d = grip_d, h = grip_depth + 1);
            translate([-grip_d / 2 - 1, -grip_bar / 2, -2]) cube([grip_d + 2, grip_bar, grip_depth + 3]);
        }
    }
}

color(print_color) {
    if (part == "body") body();
    if (part == "cap") cap();
    if (part == "both") {
        body();
        translate([R + r_plug + 8, 0, 0]) cap();
    }
    if (part == "assembled") {
        body();
        rotate([0, 0, lock_angle]) cap();
    }
}
