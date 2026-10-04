"""Measure native rendering characteristics and validate an explicit immutable pin."""


class EnvironmentMismatch(RuntimeError):
    """The requested rendering environment is incomplete or differs from observations."""


def validate_pin(pin):
    raise NotImplementedError('17-24 rendering pin schema is not implemented')


def compare_rendering(expected, actual):
    raise NotImplementedError('17-24 complete rendering comparison is not implemented')


def resolve_destinations(inventory, runtime, models):
    raise NotImplementedError('17-24 fresh destination resolution is not implemented')


def measure_environment(output, pin=None, derived_data=None):
    raise NotImplementedError('17-24 real hosted geometry measurement is not implemented')


def validate_environment(pin_path, output, derived_data=None):
    raise NotImplementedError('17-24 immutable environment validation is not implemented')
