namespace :shows do
  desc "Apply headcounts from db/data/gig_history_attendance.csv (DRY_RUN=1 to preview)"
  task import_attendance: :environment do
    dry_run = ENV["DRY_RUN"].present?
    results = AttendanceImport.new(dry_run: dry_run).call
    results.each do |r|
      puts format("%-9s %s  %-28s %4d  (show ##{r.show.id || 'new'}, %s)",
                  r.action, r.row["date"], r.row["venue"], r.row["attendance"].to_i, r.show.source)
    end
    summary = results.group_by(&:action).transform_values(&:size)
    puts "#{dry_run ? '[DRY RUN] ' : ''}#{summary.map { |k, v| "#{k}: #{v}" }.join(', ')}"
  end
end
