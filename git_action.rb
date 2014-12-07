class GitAction
  attr_accessor :git
  def initialize(git_dir)
    # @git = Git.bare(File.join("/",git_dir), :log => Logger.new(STDOUT))
    @git = Git.bare(File.join("/",git_dir))
  end

  def diff(commit1, commit2)
    dp = git.diff(commit1, commit2)
    {diff: dp.patch, stats: dp.stats}
  end
end
