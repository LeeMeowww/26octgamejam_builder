import os

BLOCKS_DIR = "assets/textures/blocks"
os.makedirs(BLOCKS_DIR, exist_ok=True)

def write_svg(filename, content):
    path = os.path.join(BLOCKS_DIR, filename)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")

# 1. BASIC (普通方块) - Modular Industrial Chassis
for i, (accent, pat) in enumerate([
    ("#4a90e2", "cross"),
    ("#50e3c2", "grid"),
    ("#7ed321", "circuit")
]):
    extra = ""
    if pat == "cross":
        extra = '<path d="M 40 40 L 88 88 M 88 40 L 40 88" stroke="{}" stroke-width="4" stroke-linecap="round" opacity="0.6"/>'.format(accent)
    elif pat == "grid":
        extra = '<rect x="44" y="44" width="40" height="40" fill="none" stroke="{}" stroke-width="3" stroke-dasharray="6,4" opacity="0.7"/>'.format(accent)
    else:
        extra = '<circle cx="64" cy="64" r="16" fill="none" stroke="{}" stroke-width="4" opacity="0.7"/><path d="M 64 36 L 64 48 M 64 80 L 64 92 M 36 64 L 48 64 M 80 64 L 92 64" stroke="{}" stroke-width="3"/>'.format(accent, accent)

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <rect x="12" y="12" width="104" height="104" rx="14" fill="#182230" stroke="#334860" stroke-width="3"/>
  <rect x="24" y="24" width="80" height="80" rx="8" fill="#1f2d3f" stroke="#2c3e55" stroke-width="2"/>
  <circle cx="28" cy="28" r="4" fill="#5c7696"/>
  <circle cx="100" cy="28" r="4" fill="#5c7696"/>
  <circle cx="28" cy="100" r="4" fill="#5c7696"/>
  <circle cx="100" cy="100" r="4" fill="#5c7696"/>
  {extra}
  <circle cx="64" cy="64" r="8" fill="{accent}"/>
</svg>'''
    write_svg(f"basic_{i}.svg", svg)

# 2. INHIBITOR (抑制器) - EMP Suppression Coil & Directional Sensor
for i, accent in enumerate(["#9013fe", "#bd10e0", "#8b572a"]):
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <rect x="12" y="12" width="104" height="104" rx="14" fill="#20142e" stroke="#48256e" stroke-width="3"/>
  <!-- Rear Suppression Pylon (Left) -->
  <path d="M 32 36 L 24 64 L 32 92 Z" fill="{accent}" opacity="0.8"/>
  <line x1="24" y1="64" x2="48" y2="64" stroke="{accent}" stroke-width="5" stroke-dasharray="4,3"/>
  <!-- Central Resonator Coil -->
  <circle cx="64" cy="64" r="26" fill="#130b1c" stroke="{accent}" stroke-width="3"/>
  <circle cx="64" cy="64" r="16" fill="{accent}" opacity="0.5"/>
  <polygon points="64,52 74,64 64,76 54,64" fill="#ffffff"/>
  <!-- Forward Detector Prism (Right) -->
  <polygon points="86,48 112,64 86,80" fill="none" stroke="{accent}" stroke-width="3.5"/>
  <circle cx="98" cy="64" r="4" fill="#ffffff"/>
  <!-- Wave Field -->
  <path d="M 104 46 Q 116 64 104 82" fill="none" stroke="{accent}" stroke-width="2.5" opacity="0.7"/>
</svg>'''
    write_svg(f"inhibitor_{i}.svg", svg)

# 3. PUSHER (推动器) - Heavy Hydraulic Ram / Kinetic Thruster
for i, accent in enumerate(["#f5a623", "#ff7700", "#e65100"]):
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <rect x="12" y="12" width="104" height="104" rx="14" fill="#2b1c0e" stroke="#5c3818" stroke-width="3"/>
  <!-- Base Anchor & Dual Cylinders (Left) -->
  <rect x="20" y="32" width="18" height="64" rx="4" fill="#3d2b1f" stroke="{accent}" stroke-width="2"/>
  <rect x="38" y="42" width="22" height="12" fill="#523927" stroke="{accent}" stroke-width="1.5"/>
  <rect x="38" y="74" width="22" height="12" fill="#523927" stroke="{accent}" stroke-width="1.5"/>
  <!-- Heavy Hydraulic Ram Piston -->
  <rect x="56" y="52" width="28" height="24" fill="{accent}" opacity="0.9"/>
  <!-- Forward Impact Head (Right) -->
  <path d="M 84 34 L 112 64 L 84 94 Z" fill="{accent}"/>
  <!-- Chevrons -->
  <path d="M 68 46 L 82 64 L 68 82" fill="none" stroke="#ffffff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="86" cy="64" r="4" fill="#ffffff"/>
</svg>'''
    write_svg(f"pusher_{i}.svg", svg)

# 4. REPLICATOR (复制器) - Dual Emitter Nanite Fabricator
for i, accent in enumerate(["#50e3c2", "#00b4d8", "#06d6a0"]):
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <rect x="12" y="12" width="104" height="104" rx="14" fill="#0d2825" stroke="#1c554e" stroke-width="3"/>
  <!-- Source Reader Funnel (Left) -->
  <path d="M 22 40 L 46 54 L 46 74 L 22 88 Z" fill="none" stroke="{accent}" stroke-width="3"/>
  <line x1="28" y1="64" x2="44" y2="64" stroke="{accent}" stroke-width="3" stroke-dasharray="3,3"/>
  <!-- Central Synthesis Core -->
  <rect x="52" y="40" width="24" height="48" rx="6" fill="#143d37" stroke="{accent}" stroke-width="2.5"/>
  <circle cx="64" cy="64" r="8" fill="{accent}"/>
  <!-- Dual Forward Projector Arms (Right) -->
  <path d="M 76 46 L 102 36 L 96 56" fill="none" stroke="{accent}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M 76 82 L 102 92 L 96 72" fill="none" stroke="{accent}" stroke-width="3.5" stroke-linejoin="round"/>
  <!-- Holographic Target Cross -->
  <circle cx="106" cy="64" r="8" fill="none" stroke="#ffffff" stroke-width="2" stroke-dasharray="4,2"/>
  <circle cx="106" cy="64" r="3" fill="#ffffff"/>
</svg>'''
    write_svg(f"replicator_{i}.svg", svg)

# 5. DESTROYER (摧毁器) - Rotary Plasma Cutter / Laser Drill
for i, accent in enumerate(["#e02020", "#ff4d4d", "#d0021b"]):
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <rect x="12" y="12" width="104" height="104" rx="14" fill="#2d1010" stroke="#5a2020" stroke-width="3"/>
  <!-- Heavy Laser Chamber (Left) -->
  <rect x="22" y="38" width="36" height="52" rx="6" fill="#421616" stroke="{accent}" stroke-width="2"/>
  <line x1="28" y1="50" x2="52" y2="50" stroke="{accent}" stroke-width="3"/>
  <line x1="28" y1="64" x2="52" y2="64" stroke="{accent}" stroke-width="3"/>
  <line x1="28" y1="78" x2="52" y2="78" stroke="{accent}" stroke-width="3"/>
  <!-- Focusing Lens Ring -->
  <ellipse cx="64" cy="64" rx="10" ry="24" fill="#1f0909" stroke="{accent}" stroke-width="3"/>
  <!-- High-Energy Plasma Spike (Right) -->
  <polygon points="70,44 114,64 70,84" fill="{accent}"/>
  <polygon points="78,54 110,64 78,74" fill="#ffffff"/>
  <!-- Warning Hazard Lines -->
  <path d="M 30 26 L 42 38 M 50 26 L 62 38" stroke="#f5a623" stroke-width="2.5"/>
</svg>'''
    write_svg(f"destroyer_{i}.svg", svg)

# 6. ROTATOR CW & CCW (转向器) - Mechanical Torque Gyro
for i, accent in enumerate(["#4a90e2", "#0077b6", "#3a86ff"]):
    # Clockwise
    svg_cw = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <rect x="12" y="12" width="104" height="104" rx="14" fill="#122336" stroke="#24456b" stroke-width="3"/>
  <circle cx="64" cy="64" r="34" fill="#18304a" stroke="{accent}" stroke-width="3"/>
  <!-- Circular CW Arc -->
  <path d="M 64 34 A 30 30 0 1 1 38 78" fill="none" stroke="{accent}" stroke-width="5" stroke-linecap="round"/>
  <!-- Arrow Head -->
  <polygon points="34,70 46,86 26,86" fill="{accent}"/>
  <!-- Central Gear Core -->
  <circle cx="64" cy="64" r="14" fill="{accent}"/>
  <circle cx="64" cy="64" r="6" fill="#ffffff"/>
  <!-- Stator Teeth -->
  <rect x="62" y="24" width="4" height="6" fill="{accent}"/>
  <rect x="62" y="98" width="4" height="6" fill="{accent}"/>
  <rect x="24" y="62" width="6" height="4" fill="{accent}"/>
  <rect x="98" y="62" width="6" height="4" fill="{accent}"/>
</svg>'''
    write_svg(f"rotator_cw_{i}.svg", svg_cw)

    # Counter-Clockwise
    svg_ccw = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <rect x="12" y="12" width="104" height="104" rx="14" fill="#122336" stroke="#24456b" stroke-width="3"/>
  <circle cx="64" cy="64" r="34" fill="#18304a" stroke="{accent}" stroke-width="3"/>
  <!-- Circular CCW Arc -->
  <path d="M 64 34 A 30 30 0 1 0 90 78" fill="none" stroke="{accent}" stroke-width="5" stroke-linecap="round"/>
  <!-- Arrow Head -->
  <polygon points="94,70 102,86 82,86" fill="{accent}"/>
  <!-- Central Gear Core -->
  <circle cx="64" cy="64" r="14" fill="{accent}"/>
  <circle cx="64" cy="64" r="6" fill="#ffffff"/>
  <!-- Stator Teeth -->
  <rect x="62" y="24" width="4" height="6" fill="{accent}"/>
  <rect x="62" y="98" width="4" height="6" fill="{accent}"/>
  <rect x="24" y="62" width="6" height="4" fill="{accent}"/>
  <rect x="98" y="62" width="6" height="4" fill="{accent}"/>
</svg>'''
    write_svg(f"rotator_ccw_{i}.svg", svg_ccw)

# 7. HARD (坚硬方块) - Armored Titanium Bulkhead
for i, accent in enumerate(["#8e9aaf", "#6c757d", "#495057"]):
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <rect x="10" y="10" width="108" height="108" rx="8" fill="#212529" stroke="{accent}" stroke-width="4"/>
  <rect x="24" y="24" width="80" height="80" rx="4" fill="#343a40" stroke="#111" stroke-width="3"/>
  <!-- Reinforced Braces -->
  <line x1="24" y1="24" x2="104" y2="104" stroke="{accent}" stroke-width="4"/>
  <line x1="104" y1="24" x2="24" y2="104" stroke="{accent}" stroke-width="4"/>
  <!-- Central Shield Boss -->
  <polygon points="64,44 84,64 64,84 44,64" fill="{accent}"/>
  <circle cx="64" cy="64" r="6" fill="#ffffff"/>
  <!-- Heavy Industrial Rivets -->
  <circle cx="18" cy="18" r="5" fill="{accent}"/>
  <circle cx="110" cy="18" r="5" fill="{accent}"/>
  <circle cx="18" cy="110" r="5" fill="{accent}"/>
  <circle cx="110" cy="110" r="5" fill="{accent}"/>
</svg>'''
    write_svg(f"hard_{i}.svg", svg)

# 8. WANDERER (游荡怪物) - Autonomous Patrol Drone / Rover
for i, accent in enumerate(["#ff595e", "#ffca3a", "#8ac926"]):
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <rect x="12" y="12" width="104" height="104" rx="14" fill="#231924" stroke="#4a2e4d" stroke-width="3"/>
  <!-- Chassis Base & Treads (Bottom) -->
  <rect x="24" y="86" width="80" height="20" rx="8" fill="#161017" stroke="{accent}" stroke-width="2"/>
  <circle cx="36" cy="96" r="6" fill="{accent}"/>
  <circle cx="64" cy="96" r="6" fill="{accent}"/>
  <circle cx="92" cy="96" r="6" fill="{accent}"/>
  <!-- Robotic Drone Body -->
  <rect x="34" y="44" width="60" height="38" rx="8" fill="#38213b" stroke="{accent}" stroke-width="2.5"/>
  <!-- Scanner Eye & Laser Vizor (Forward Right) -->
  <rect x="54" y="52" width="34" height="14" rx="4" fill="#110712"/>
  <line x1="56" y1="59" x2="86" y2="59" stroke="{accent}" stroke-width="4"/>
  <circle cx="82" cy="59" r="4" fill="#ffffff"/>
  <!-- Sensor Antenna -->
  <line x1="48" y1="44" x2="42" y2="26" stroke="{accent}" stroke-width="3"/>
  <circle cx="42" cy="26" r="4" fill="{accent}"/>
  <line x1="94" y1="59" x2="114" y2="59" stroke="{accent}" stroke-width="2" stroke-dasharray="3,2"/>
</svg>'''
    write_svg(f"wanderer_{i}.svg", svg)

# 9. TREASURE (宝藏) - Quantum Data Core / Power Relic
for i, accent in enumerate(["#ffd166", "#f77f00", "#e9c46a"]):
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <rect x="12" y="12" width="104" height="104" rx="14" fill="#292211" stroke="#614e20" stroke-width="3"/>
  <!-- Outer Crystalline Octagon -->
  <polygon points="64,20 96,36 108,68 92,100 64,108 36,100 20,68 32,36" fill="#382e17" stroke="{accent}" stroke-width="3"/>
  <!-- Radiant Core -->
  <polygon points="64,34 88,64 64,94 40,64" fill="{accent}"/>
  <polygon points="64,46 76,64 64,82 52,64" fill="#ffffff"/>
  <!-- Energy Sparkles -->
  <circle cx="64" cy="64" r="5" fill="#ffffff"/>
  <circle cx="34" cy="34" r="3" fill="{accent}"/>
  <circle cx="94" cy="34" r="3" fill="{accent}"/>
  <circle cx="34" cy="94" r="3" fill="{accent}"/>
  <circle cx="94" cy="94" r="3" fill="{accent}"/>
</svg>'''
    write_svg(f"treasure_{i}.svg", svg)

# 10. POLLUTION (污染源) - Toxic Radiation Hazard Core
for i, accent in enumerate(["#d90429", "#ef233c", "#9b5de5"]):
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <rect x="12" y="12" width="104" height="104" rx="14" fill="#240c12" stroke="#571624" stroke-width="3"/>
  <!-- Radiation Warning Triangle -->
  <polygon points="64,24 104,96 24,96" fill="#3d141e" stroke="{accent}" stroke-width="3"/>
  <!-- Trefoil Hazardous Core -->
  <circle cx="64" cy="68" r="10" fill="{accent}"/>
  <circle cx="64" cy="50" r="7" fill="{accent}"/>
  <circle cx="50" cy="74" r="7" fill="{accent}"/>
  <circle cx="78" cy="74" r="7" fill="{accent}"/>
  <circle cx="64" cy="68" r="4" fill="#240c12"/>
  <!-- Biohazard Spikes -->
  <path d="M 64 16 L 64 24 M 108 100 L 100 94 M 20 100 L 28 94" stroke="{accent}" stroke-width="3" stroke-linecap="round"/>
</svg>'''
    write_svg(f"pollution_{i}.svg", svg)

# 11. PROTECTED (受保护方块) - Cryo-Stasis Chamber / Bio-Embryo Core
for i, accent in enumerate(["#06d6a0", "#118ab2", "#48cae4"]):
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <rect x="12" y="12" width="104" height="104" rx="14" fill="#0d2329" stroke="#1b4952" stroke-width="3"/>
  <!-- Protective Hexagonal Shell -->
  <polygon points="64,22 100,42 100,86 64,106 28,86 28,42" fill="#13363d" stroke="{accent}" stroke-width="3"/>
  <!-- Inner Stasis Pod Capsule -->
  <rect x="46" y="36" width="36" height="56" rx="18" fill="#1c4e57" stroke="{accent}" stroke-width="2"/>
  <!-- Glowing Vital Embryo Core -->
  <ellipse cx="64" cy="64" rx="10" ry="14" fill="{accent}"/>
  <ellipse cx="64" cy="62" rx="5" ry="8" fill="#ffffff"/>
  <!-- Shield Energy Nodes -->
  <circle cx="28" cy="42" r="3.5" fill="{accent}"/>
  <circle cx="100" cy="42" r="3.5" fill="{accent}"/>
  <circle cx="28" cy="86" r="3.5" fill="{accent}"/>
  <circle cx="100" cy="86" r="3.5" fill="{accent}"/>
  <line x1="64" y1="22" x2="64" y2="36" stroke="{accent}" stroke-width="2.5"/>
  <line x1="64" y1="92" x2="64" y2="106" stroke="{accent}" stroke-width="2.5"/>
</svg>'''
    write_svg(f"protected_{i}.svg", svg)

print("Generated all mechanical block SVGs successfully!")
