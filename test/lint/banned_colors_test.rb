require "test_helper"

# Regression guard for the CEC color system (Navy · Gold · Teal).
#
# Fails if any view or component introduces a Tailwind utility class
# from a banned color family. Amber is intentionally allowed for the
# "Notas de tu cuenta" info card and similar informational panels.
class BannedColorsTest < ActiveSupport::TestCase
  BANNED = %w[emerald green lime sky cyan indigo violet purple fuchsia pink rose orange yellow].freeze
  SCAN_DIRS = ["app/views", "app/components"].freeze
  ALLOWLIST = [].freeze # absolute paths of files to skip, if ever needed

  test "no banned tailwind color tones leak into views or components" do
    offenders = []

    prefixes = %w[text bg border ring from to via divide outline decoration shadow accent fill stroke placeholder caret]
    prefix_alt = prefixes.join("|")
    tone_alt = BANNED.join("|")
    pattern = /\b(?:#{prefix_alt})-(?:#{tone_alt})-\d{2,3}\b/

    SCAN_DIRS.each do |dir|
      Dir.glob(Rails.root.join(dir, "**", "*.{erb,rb}")).each do |file|
        next if ALLOWLIST.include?(file)

        File.read(file).each_line.with_index(1) do |line, line_no|
          line.scan(pattern).each do |match|
            offenders << "#{file}:#{line_no}  #{match}"
          end
        end
      end
    end

    assert_empty offenders,
      "Banned color tones found — the CEC palette is Navy · Gold · Teal only:\n#{offenders.join("\n")}"
  end
end
