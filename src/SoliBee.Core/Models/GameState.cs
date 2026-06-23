namespace SoliBee.Core.Models;

public enum DrawMode
{
    DrawOne,
    DrawThree
}

public class GameState
{
    public int Score { get; set; }
    public int MovesCount { get; set; }
    public int TimerSeconds { get; set; }
    public bool IsTimerActive { get; set; }
    public bool HasWon { get; set; }
    public int RecyclesCount { get; set; }
    public DrawMode Mode { get; set; }
}
