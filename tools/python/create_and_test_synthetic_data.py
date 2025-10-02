#!/usr/bin/env python3
"""
This script creates synthetic eye‑tracking and behavioural data files that
mirror the structure produced by the CSN experiment’s MATLAB task
(stored as `.mat` files containing `subjdata` and `Edf2Mat`).  It then
verifies that the generated files adhere to the expected schema and
data types used by the `itrackvalr` package.

Requirements:
    - Python 3.8+
    - numpy
    - scipy (for reading/writing .mat files)

Usage:
    python create_and_test_synthetic_data.py --output-dir ./synthetic

The script will generate one `.mat` file per participant in the
specified output directory and then run a suite of assertions to
ensure the data meet the requirements (fields, shapes, and types).

The FSAMPLE fields follow SR Research’s EyeLink data specification
for sample structures, which include time stamps, gaze positions and
pupil area【599156185568903†L50-L69】.  Only the right eye (index 1)
contains non‑missing data; the left eye (index 0) is filled with NaNs
to reflect monocular recording【599156185568903†L50-L69】.
"""

import argparse
import os
import numpy as np
import scipy.io


def create_synthetic_participant(
    participant_id: int,
    n_trials: int = 60,
    samplerate: int = 500,
    p_signal: float = 0.01,  # Match task.m: 1% signal probability
    trial_duration_ms: int = 1000,
    seed: int | None = None,
    full_scale: bool = False,  # If True, create 3600 trials like real CSN
) -> tuple[dict, dict]:
    """Generate synthetic subjdata and Edf2Mat for a single participant.
    
    NOTE: By default uses n_trials=60 for testing efficiency. Set full_scale=True
    for n_trials=3600 (60 minutes) matching real CSN task.m data.

    Args:
        participant_id: Numeric ID used to seed random number generator.
        n_trials: Number of trials (60 for testing; real task uses 3600).
        samplerate: Sampling rate in Hz for gaze samples.
        p_signal: Probability that a "signal" (double movement) occurs.
          Real task.m uses 0.01 (1%). Default matches reality.
        trial_duration_ms: Duration of each trial in milliseconds.
        seed: Optional additional seed for RNG; if None, uses participant_id.
        full_scale: If True, override n_trials to 3600 (real CSN scale).

    Returns:
        (subjdata, Edf2Mat) as Python dictionaries suitable for
        conversion to MATLAB structs via scipy.io.savemat.
        
    Structure matches task.m output:
        - subjdata.lr: SCALAR (0 or 1) for which side clock is on
        - subjdata.steps: (n_trials, 2) with [signal_flag, signal_time_ms]
        - subjdata.resps: (n_trials, 2) with [response_flag, response_time_ms]
    """
    # Use a deterministic seed per participant (plus optional extra seed)
    rng_seed = participant_id if seed is None else (participant_id * 1000 + seed)
    rng = np.random.default_rng(rng_seed)

    # Override n_trials if full_scale requested
    if full_scale:
        n_trials = 3600  # Real CSN task duration (60 minutes)
    
    total_time_ms = n_trials * trial_duration_ms
    dt_ms = 1000 / samplerate  # sample spacing in ms
    times = np.arange(0, total_time_ms, dt_ms, dtype=float)
    n_samples = len(times)

    # Determine clock side FIRST (needed for gaze generation)
    # lr is a SCALAR (0 or 1) for entire session - which side clock is on
    # Per task.m line 260: lr = rand < 0.5 (scalar, not vector!)
    lr = float(rng.random() < 0.5)  # 0 = clock left, 1 = clock right
    
    # Allocate gaze arrays: two rows (LEFT_EYE=0, RIGHT_EYE=1)
    gx = np.empty((2, n_samples), dtype=float)
    gy = np.empty((2, n_samples), dtype=float)
    pa = np.empty((2, n_samples), dtype=float)

    # Fill left eye with NaNs (monocular recording)
    gx[0, :] = np.nan
    gy[0, :] = np.nan
    pa[0, :] = np.nan

    # Generate realistic gaze tracking the clock hand with attention shifts
    # Per task.m lines 260-271: clock and image are offset left/right by width/4
    # Screen: 1280x1024, center would be (640, 512)
    # But clock is shifted: lr=0 (LEFT) → x=320, lr=1 (RIGHT) → x=960
    screen_width, screen_height = 1280.0, 1024.0
    screen_center_x, screen_center_y = screen_width / 2, screen_height / 2
    
    # Clock position based on lr
    if lr == 0:  # Clock LEFT
        clock_center_x = screen_center_x - screen_width / 4  # 640 - 320 = 320
        image_center_x = screen_center_x + screen_width / 4  # 640 + 320 = 960
    else:  # Clock RIGHT (lr == 1)
        clock_center_x = screen_center_x + screen_width / 4  # 640 + 320 = 960
        image_center_x = screen_center_x - screen_width / 4  # 640 - 320 = 320
    
    clock_center_y = screen_center_y  # Y stays centered
    image_center_y = screen_center_y
    
    # Clock dimensions
    hand_length = (min(screen_width, screen_height) / 3.0) * 0.45
    
    # Generate gaze that tracks hand with some attention to images
    for i, t_ms in enumerate(times):
        # Which trial are we in?
        trial_idx = min(int(t_ms / trial_duration_ms), n_trials - 1)
        t_in_trial = t_ms - (trial_idx * trial_duration_ms)
        
        # Clock hand angle (rotates continuously, ~360° per minute)
        angle_deg = (t_ms / total_time_ms) * 360 * (n_trials / 60)
        angle_rad = angle_deg * np.pi / 180
        
        # Clock hand tip position (from clock center, not screen center!)
        hand_tip_x = clock_center_x + hand_length * np.sin(angle_rad)
        hand_tip_y = clock_center_y - hand_length * np.cos(angle_rad)
        
        # Attention state: mostly on clock, sometimes on image
        # Higher attention to image in first 300ms of trial
        if t_in_trial < 300:
            # Looking at image (60% probability)
            if rng.random() < 0.6:
                # Gaze at image center with some noise
                target_x = image_center_x + rng.standard_normal() * 50
                target_y = image_center_y + rng.standard_normal() * 50
            else:
                target_x, target_y = hand_tip_x, hand_tip_y
        else:
            # Looking at clock hand (80% probability after image onset period)
            if rng.random() < 0.8:
                target_x, target_y = hand_tip_x, hand_tip_y
            else:
                # Occasional saccade away (random on screen)
                target_x = rng.random() * screen_width
                target_y = rng.random() * screen_height
        
        # Add measurement noise (tracker imprecision)
        noise_x = rng.standard_normal() * 15  # 15 px SD (realistic for remote mode)
        noise_y = rng.standard_normal() * 15
        
        gx[1, i] = target_x + noise_x
        gy[1, i] = target_y + noise_y
        pa[1, i] = 1500.0 + 50.0 * rng.standard_normal()
        
        # Occasional blinks (pupil = 0)
        if rng.random() < 0.002:  # 0.2% blink rate
            pa[1, i] = 0.0

    # Build Edf2Mat.FSAMPLE
    fsample = {
        'time': times,
        'gx': gx,
        'gy': gy,
        'pa': pa,
    }

    # Prepare behavioural fields
    # Note: lr already defined above (before gaze generation)
    resps = np.zeros((n_trials, 2), dtype=float)
    steps = np.zeros((n_trials, 2), dtype=float)
    img_ind = np.zeros(n_trials, dtype=float)
    
    # Determine which trials have signals
    # Ensure at least 1 signal for testing (real task.m doesn't guarantee this)
    n_signal_trials = max(1, int(np.round(n_trials * p_signal)))
    signal_trial_indices = rng.choice(n_trials, size=n_signal_trials, replace=False)

    event_times: list[float] = []
    event_msgs: list[str] = []

    # Pre‑task calibration message with participant-specific variation
    # Realistic range: 0.3-1.2° avg error, 0.8-2.5° max error
    pre_avg_err = 0.4 + rng.random() * 0.8  # 0.4-1.2°
    pre_max_err = pre_avg_err + 0.4 + rng.random() * 0.6  # +0.4 to +1.0° from avg
    pre_offset_x = -20 + rng.random() * 40  # -20 to +20 px
    pre_offset_y = -20 + rng.random() * 40  # -20 to +20 px
    
    event_times.append(0.0)
    event_msgs.append(f'!CAL VALIDATION pre avg_err={pre_avg_err:.2f} max_err={pre_max_err:.2f} offset=({pre_offset_x:.1f},{pre_offset_y:.1f})')

    # Trial loop: populate behavioural arrays and events
    for t in range(n_trials):
        trial_start = t * trial_duration_ms
        # Assign random image ID (1–10)
        img_idx = rng.integers(1, 11)
        img_ind[t] = img_idx
        # Determine if this is a signal trial (using pre-determined indices)
        is_signal = t in signal_trial_indices
        steps[t, 0] = 1.0 if is_signal else 0.0
        # Step time: middle of the trial
        step_time = trial_start + 500.0
        steps[t, 1] = step_time
        # Generate response: hits on signal trials, rare false alarms on non‑signal
        response_flag = 0.0
        response_time = 0.0
        if is_signal:
            if rng.random() < 0.7:
                response_flag = 1.0
                response_time = step_time + float(rng.integers(200, 600))
        else:
            if rng.random() < 0.05:
                response_flag = 1.0
                response_time = trial_start + float(rng.integers(200, 800))
        resps[t, 0] = response_flag
        resps[t, 1] = response_time
        # Image events
        image_name = f'image_{int(img_idx):03d}.jpg'
        event_times.append(float(trial_start))
        event_msgs.append(f'image_onset {image_name}')
        event_times.append(float(trial_start + trial_duration_ms))
        event_msgs.append(f'image_offset {image_name}')
        # Signal and response events
        if is_signal:
            event_times.append(step_time)
            event_msgs.append('signal_on')
        if response_flag:
            event_times.append(response_time)
            event_msgs.append('response')

    # Post‑task calibration message with slight drift from pre
    # Simulate calibration degradation over session (typically small)
    drift_factor = 1.0 + (rng.random() * 0.4 - 0.2)  # 0.8-1.2x (±20% drift)
    post_avg_err = pre_avg_err * drift_factor
    post_max_err = pre_max_err * drift_factor
    post_offset_x = pre_offset_x + rng.standard_normal() * 5  # ±5 px drift
    post_offset_y = pre_offset_y + rng.standard_normal() * 5
    
    post_val_time = float(total_time_ms + 1000)
    event_times.append(post_val_time)
    event_msgs.append(f'!CAL VALIDATION post avg_err={post_avg_err:.2f} max_err={post_max_err:.2f} offset=({post_offset_x:.1f},{post_offset_y:.1f})')

    # Sort events chronologically
    order = np.argsort(event_times)
    event_times_sorted = np.array(event_times, dtype=float)[order]
    event_msgs_sorted = [event_msgs[idx] for idx in order]

    fevent = {
        'time': event_times_sorted,
        'msg': np.array(event_msgs_sorted, dtype=object),
    }
    recordings = {
        'duration': float(total_time_ms),
        'start': 0.0,
        'end': float(total_time_ms),
        'samplerate': float(samplerate),
    }
    edf2mat = {
        'FSAMPLE': fsample,
        'FEVENT': fevent,
        'RECORDINGS': recordings,
    }
    subjdata = {
        'nTrials': float(n_trials),
        'pSignal': float(p_signal),
        'lr': lr,
        'resps': resps,
        'steps': steps,
        'img_ind': img_ind,
        'image_names': np.array([f'image_{i:03d}.jpg' for i in range(1, 11)], dtype=object),
        'expBegin': 0.0,
        'expEnd': float(total_time_ms),
    }
    return subjdata, edf2mat


def save_synthetic_files(num_participants: int, output_dir: str, prefix: str = "synthetic", full_scale: bool = False) -> list[str]:
    """Generate and save synthetic .mat files for a given number of participants.

    Args:
        num_participants: Number of participant files to create.
        output_dir: Directory where .mat files will be saved.
        prefix: Filename prefix (default: "synthetic", use "CSN" for real-like names)
        full_scale: If True, create 3600-trial data (like real CSN)

    Returns:
        A list of file paths for the created .mat files.
    """
    os.makedirs(output_dir, exist_ok=True)
    file_paths: list[str] = []
    for pid in range(1, num_participants + 1):
        subjdata, edf2mat = create_synthetic_participant(pid, full_scale=full_scale)
        if prefix == "CSN":
            filename = os.path.join(output_dir, f'CSN{pid:03d}_synthetic.mat')
        else:
            filename = os.path.join(output_dir, f'{prefix}_{pid:02d}.mat')
        scipy.io.savemat(filename, {'subjdata': subjdata, 'Edf2Mat': edf2mat})
        file_paths.append(filename)
        if pid % 10 == 0:
            print(f"  Generated {pid}/{num_participants} participants...")
    return file_paths


def test_synthetic_file(mat_path: str) -> None:
    """Load a synthetic .mat file and assert that it meets the schema requirements.

    The function checks for the presence of expected variables and fields, correct
    data types and shapes, and non‑missing right‑eye data.  It raises an
    AssertionError if any check fails.

    Args:
        mat_path: Path to the .mat file to test.
    """
    data = scipy.io.loadmat(mat_path, squeeze_me=True)
    assert 'subjdata' in data and 'Edf2Mat' in data, (
        f"File {mat_path} must contain 'subjdata' and 'Edf2Mat' variables"
    )

    subjdata = data['subjdata']
    # Access subjdata and Edf2Mat fields via dtype names, mapping or attributes
    def field_exists(obj, name):
        """Check if a field exists in a MATLAB struct loaded via loadmat."""
        if isinstance(obj, np.ndarray) and obj.dtype.names:
            return name in obj.dtype.names
        if isinstance(obj, dict):
            return name in obj
        return hasattr(obj, name)

    def get_field(obj, name):
        """Retrieve a field from a MATLAB struct loaded via loadmat."""
        if isinstance(obj, np.ndarray) and obj.dtype.names:
            # Structured array: return the field's value and squeeze any zero‑dim
            return obj[name].item()
        if isinstance(obj, dict):
            return obj[name]
        return getattr(obj, name)

    # Check required fields exist
    required_subj_fields = [
        'nTrials', 'pSignal', 'lr', 'resps', 'steps', 'img_ind',
        'image_names', 'expBegin', 'expEnd'
    ]
    for field in required_subj_fields:
        assert field_exists(subjdata, field), (
            f"Missing '{field}' in subjdata of {mat_path}"
        )

    # Helper to convert MATLAB arrays to numpy arrays
    def to_ndarray(obj):
        # Convert MATLAB object arrays (dtype 'O') to regular ndarrays
        if isinstance(obj, np.ndarray):
            if obj.dtype == object:
                return np.array(obj.tolist())
            return obj
        return np.array(obj)

    n_trials = int(get_field(subjdata, 'nTrials'))
    assert n_trials == 60, (
        f"nTrials should be 60 but got {n_trials} in {mat_path}"
    )
    # pSignal should be a float between 0 and 1
    p_signal = float(get_field(subjdata, 'pSignal'))
    assert 0.0 <= p_signal <= 1.0, "pSignal must be in [0, 1]"
    # lr is a SCALAR (0 or 1) indicating which side clock is on for entire session
    lr_raw = get_field(subjdata, 'lr')
    lr = float(lr_raw) if np.isscalar(lr_raw) or (hasattr(lr_raw, 'size') and lr_raw.size == 1) else float(lr_raw.flatten()[0])
    assert lr in [0.0, 1.0], (
        f"lr should be 0 (left) or 1 (right) but got {lr}"
    )
    # resps, steps must have appropriate shapes
    resps_raw = get_field(subjdata, 'resps')
    resps = to_ndarray(resps_raw).astype(float)
    assert resps.shape == (n_trials, 2), (
        f"resps should be of shape ({n_trials}, 2) but got {resps.shape}"
    )
    steps_raw = get_field(subjdata, 'steps')
    steps = to_ndarray(steps_raw).astype(float)
    assert steps.shape == (n_trials, 2), (
        f"steps should be of shape ({n_trials}, 2) but got {steps.shape}"
    )
    img_ind_raw = get_field(subjdata, 'img_ind')
    img_ind = to_ndarray(img_ind_raw).astype(float)
    assert img_ind.shape == (n_trials,), (
        f"img_ind should have shape ({n_trials},) but got {img_ind.shape}"
    )
    image_names = get_field(subjdata, 'image_names')
    # Convert to list of strings if necessary
    if isinstance(image_names, np.ndarray) and image_names.dtype == object:
        image_names_list = [str(item) for item in image_names.tolist()]
    else:
        image_names_list = list(image_names)
    assert len(image_names_list) > 0 and all(isinstance(name, str) for name in image_names_list), (
        "image_names must be a sequence of strings"
    )
    # expBegin and expEnd must be numeric
    expBegin = get_field(subjdata, 'expBegin')
    expEnd = get_field(subjdata, 'expEnd')
    assert isinstance(expBegin, (int, float, np.integer, np.floating))
    assert isinstance(expEnd, (int, float, np.integer, np.floating))

    edf2mat = data['Edf2Mat']
    # Check FSAMPLE, FEVENT and RECORDINGS exist
    for key in ['FSAMPLE', 'FEVENT', 'RECORDINGS']:
        assert field_exists(edf2mat, key), (
            f"Missing '{key}' in Edf2Mat of {mat_path}"
        )

    fsample = get_field(edf2mat, 'FSAMPLE')
    # Check FSAMPLE fields
    for ffield in ['time', 'gx', 'gy', 'pa']:
        assert field_exists(fsample, ffield), (
            f"Missing '{ffield}' in FSAMPLE of {mat_path}"
        )
    # Confirm shapes and eye rows
    time_vec = to_ndarray(get_field(fsample, 'time')).astype(float)
    gx = to_ndarray(get_field(fsample, 'gx')).astype(float)
    gy = to_ndarray(get_field(fsample, 'gy')).astype(float)
    pa = to_ndarray(get_field(fsample, 'pa')).astype(float)
    assert gx.shape[0] == 2 and gy.shape[0] == 2 and pa.shape[0] == 2, (
        "gx, gy and pa matrices must have two rows (LEFT and RIGHT eye)"
    )
    # Right eye (row index 1) should have finite values
    assert np.isfinite(gx[1, :]).any(), "Right‑eye gx must contain non‑NaN values"
    assert np.isfinite(gy[1, :]).any(), "Right‑eye gy must contain non‑NaN values"
    assert np.isfinite(pa[1, :]).any(), "Right‑eye pa must contain non‑NaN values"
    # Left eye (row index 0) should be NaN
    assert np.all(np.isnan(gx[0, :])), "Left‑eye gx should be NaN for monocular data"
    assert np.all(np.isnan(gy[0, :])), "Left‑eye gy should be NaN for monocular data"
    assert np.all(np.isnan(pa[0, :])), "Left‑eye pa should be NaN for monocular data"

    # Check FEVENT fields
    fevent = get_field(edf2mat, 'FEVENT')
    assert field_exists(fevent, 'time'), (
        f"Missing 'time' in FEVENT of {mat_path}"
    )
    assert field_exists(fevent, 'msg'), (
        f"Missing 'msg' in FEVENT of {mat_path}"
    )
    # FEVENT times must be sorted and numeric
    fevent_times = to_ndarray(get_field(fevent, 'time')).astype(float)
    assert np.all(np.diff(fevent_times) >= 0), (
        "FEVENT times must be non‑decreasing"
    )
    # FEVENT messages must be strings
    fevent_msgs_obj = get_field(fevent, 'msg')
    if isinstance(fevent_msgs_obj, np.ndarray) and fevent_msgs_obj.dtype == object:
        fevent_msgs = [str(m) for m in fevent_msgs_obj.tolist()]
    else:
        fevent_msgs = [str(m) for m in fevent_msgs_obj]
    assert all(isinstance(m, str) for m in fevent_msgs), (
        "FEVENT messages must be strings"
    )

    # Check RECORDINGS fields
    recordings = get_field(edf2mat, 'RECORDINGS')
    for rfield in ['duration', 'start', 'end', 'samplerate']:
        assert field_exists(recordings, rfield), (
            f"Missing '{rfield}' in RECORDINGS of {mat_path}"
        )
    samplerate = float(get_field(recordings, 'samplerate'))
    assert samplerate == 500.0, (
        f"samplerate must be 500 Hz but got {samplerate} in {mat_path}"
    )

    # All checks passed
    print(f"File '{os.path.basename(mat_path)}' passed validation.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Create and test synthetic CSN eye‑tracking data.")
    parser.add_argument('--num-participants', type=int, default=5, help='Number of participants to generate')
    parser.add_argument('--output-dir', type=str, default='synthetic_data', help='Directory to save .mat files')
    parser.add_argument('--prefix', type=str, default='synthetic', help='Filename prefix (use "CSN" for real-like names)')
    parser.add_argument('--full-scale', action='store_true', help='Create 3600 trials per participant (real CSN scale)')
    parser.add_argument('--validate', action='store_true', help='Run validation tests on generated files')
    args = parser.parse_args()

    n_trials_info = "3600 trials (full scale)" if args.full_scale else "60 trials (testing)"
    print(f"Generating {args.num_participants} synthetic participants with realistic variation ({n_trials_info})...")
    file_paths = save_synthetic_files(args.num_participants, args.output_dir, args.prefix, args.full_scale)
    print(f"\n✅ Generated {len(file_paths)} synthetic .mat files in '{args.output_dir}'.")
    
    # Run validation on each file if requested
    if args.validate:
        print("\nValidating generated files...")
        for path in file_paths:
            test_synthetic_file(path)
        print("✅ All synthetic files validated successfully.")
    else:
        print("\nSkip validation with --validate flag if needed.")


if __name__ == '__main__':
    main()