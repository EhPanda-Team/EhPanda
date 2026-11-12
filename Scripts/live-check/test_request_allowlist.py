"""The daily live check reads pages with GET only (19-14; 19-CONTEXT D-21 as narrowed at planning; T-19-30).

`LiveCheckTests` may name only the request types on the allowlist. Every request type in `NetworkingFeature` that
sends a POST, or that asks the gallery API for titles (a POST) on the way, is found from the sources and must not be
on the allowlist. The Swift offline tests prove the same at run time: a run sends only GET and the GET-only session
refuses nothing.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
LIVE_CHECK = ROOT / 'AppPackage/Tests/LiveCheckTests'
NETWORKING = ROOT / 'AppPackage/Sources/NetworkingFeature'
ALLOWED = {'GalleryDetailRequest', 'ThumbnailURLsRequest', 'GalleryNormalImageURLsRequest', 'DataRequest',
           'TagTranslatorRequest', 'ReportFormRequest'}
# Foundation's request value, not an app request type.
NEUTRAL = {'URLRequest'}
POST_MARKERS = ('httpMethod = "POST"', 'gdataResponse(', 'GalleriesMetadataRequest(', 'galleriesWithTitles(')


def strip_comments(source):
    """Swift source without `//` comments, so a type is judged by the code that uses it."""
    return re.sub(r'//[^\n]*', '', source)


def request_types(source):
    """Every `...Request` type name the code mentions."""
    return set(re.findall(r'\b([A-Z][A-Za-z0-9]*Request)\b', strip_comments(source))) - NEUTRAL


def violations(source):
    """Request types outside the allowlist, and any POST written directly, in one Swift source."""
    found = sorted(request_types(source) - ALLOWED)
    if re.search(r'httpMethod\s*=\s*"POST"', strip_comments(source)):
        found.append('httpMethod = "POST"')
    return found


def request_bodies():
    """`{type: source of its declaration up to the next top-level declaration}` for every app request type."""
    bodies = {}
    for path in sorted(NETWORKING.glob('Request*.swift')):
        source = path.read_text()
        starts = [(match.start(), match.group(1)) for match in
                  re.finditer(r'^public struct (\w+Request)\b', source, re.M)]
        tops = [match.start() for match in re.finditer(r'^\S', source, re.M)]
        for start, name in starts:
            end = next((top for top in tops if top > start), len(source))
            bodies[name] = source[start:end]
    return bodies


def post_types():
    """Request types that send a POST themselves or through the gallery API title query."""
    return {name for name, body in request_bodies().items() if any(marker in body for marker in POST_MARKERS)}


class RequestAllowlistTests(unittest.TestCase):
    def test_live_check_names_only_allowed_request_types(self):
        sources = sorted(LIVE_CHECK.rglob('*.swift'))
        self.assertGreater(len(sources), 5)
        for path in sources:
            self.assertEqual(violations(path.read_text()), [], path.name)

    def test_allowlist_holds_no_post_type(self):
        posting = post_types()
        self.assertTrue({'SendReportRequest', 'LoginRequest', 'GalleryMPVImageURLRequest',
                         'FrontPageGalleriesRequest', 'ToplistsGalleriesRequest'} <= posting, sorted(posting))
        self.assertEqual(ALLOWED & posting, set())
        self.assertTrue(ALLOWED <= set(request_bodies()), 'an allowed type no longer exists')

    def test_a_source_naming_send_report_fails(self):
        source = 'let request = SendReportRequest(url: url, fields: fields)\n'
        self.assertEqual(violations(source), ['SendReportRequest'])

    def test_a_source_posting_directly_fails(self):
        source = 'var request = URLRequest(url: url)\nrequest.httpMethod = "POST"\n'
        self.assertEqual(violations(source), ['httpMethod = "POST"'])

    def test_a_list_request_type_fails_and_comments_do_not(self):
        self.assertEqual(violations('_ = try await PopularGalleriesRequest(host: host).response()\n'),
                         ['PopularGalleriesRequest'])
        self.assertEqual(violations('// Not PopularGalleriesRequest: it also posts.\n'), [])


if __name__ == '__main__':
    unittest.main()
