#!/usr/bin/env bash
# בס"ד — בדיקת היצמדות למערכת העיצוב של LEV
# הרצה: bash tool/check_design.sh
set -uo pipefail

fail=0
report() { echo "❌ $1"; shift; echo "$@" | sed 's/^/     /'; fail=1; }

scan() { # scan <pattern> <message> [extra-exclude]
  local pattern="$1" msg="$2"
  local hits
  hits=$(grep -rn --include='*.dart' -E "$pattern" lib/ \
         | grep -v 'lib/core/theme/app_theme.dart' \
         | grep -v 'lib/core/widgets/lev_widgets.dart' || true)
  [ -n "$hits" ] && report "$msg" "$hits"
}

echo "בודק היצמדות למערכת העיצוב…"
echo

scan 'Color\(0x'                'צבע קשיח בקוד. כל צבע מגיע מ-LevColors.'
scan 'Colors\.(red|blue|green|grey|gray|black|white|amber|teal|orange)' \
                                'צבע של Material במקום טוקן של LEV.'
scan 'EdgeInsets\.only\([^)]*(left|right):' \
                                'EdgeInsets עם left/right — שובר RTL. להשתמש ב-EdgeInsetsDirectional.'
scan 'EdgeInsets\.fromLTRB'     'fromLTRB שובר RTL. להשתמש ב-EdgeInsetsDirectional.fromSTEB.'
scan 'Alignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)' \
                                'Alignment קבוע — שובר RTL. להשתמש ב-AlignmentDirectional.'
scan 'google_fonts'             'google_fonts מוריד פונט מהרשת. קריאת רשת היא באג.'
scan 'ElevatedButton|FilledButton\(|TextButton\(|OutlinedButton\(' \
                                'כפתור של Material במקום LevButton.'

# מספרי מרווח שאינם בסולם 4·8·12·16·24·32·48·64
odd=$(grep -rn --include='*.dart' -E '(SizedBox\((width|height): |padding: EdgeInsetsDirectional\.all\()[0-9]+' lib/ \
      | grep -vE '[^0-9](4|8|12|16|24|32|48|64)[^0-9.]' \
      | grep -v 'lib/core/' || true)
[ -n "$odd" ] && report 'מרווח שאינו בסולם (4·8·12·16·24·32·48·64) — להשתמש ב-LevSpace.' "$odd"

echo
if [ "$fail" -eq 0 ]; then
  echo "✅ הכול נקי."
else
  echo "נמצאו סטיות ממערכת העיצוב. לתקן, לא לעקוף."
fi
exit "$fail"
