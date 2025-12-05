#!/usr/bin/env python3
"""
Termux Auth System - Project Info
This is a Termux CLI authentication tool designed to run on Android/Termux.
"""

from rich.console import Console
from rich.panel import Panel
from rich.table import Table

console = Console()

def show_project_info():
    console.print()
    
    title_panel = Panel(
        "[bold white]TERMUX AUTH SYSTEM[/bold white]\n[dim]by XyraOfficial[/dim]",
        border_style="cyan",
        padding=(1, 4)
    )
    console.print(title_panel)
    console.print()
    
    table = Table(title="Project Structure", show_header=True, header_style="bold cyan")
    table.add_column("Folder", style="green")
    table.add_column("Description", style="white")
    table.add_column("Status", style="yellow")
    
    table.add_row("encrypt/", "Source code & build scripts", "Developer only")
    table.add_row("run/", "Distribution files", "For end users")
    table.add_row("", "", "")
    
    console.print(table)
    console.print()
    
    info_panel = Panel(
        "[bold green]How to Use:[/bold green]\n\n"
        "[white]1.[/white] [cyan]Developer:[/cyan] Edit encrypt/config.json, run encrypt_config.py\n"
        "[white]2.[/white] [cyan]Build:[/cyan] Compile on Termux with setup_termux.sh\n"
        "[white]3.[/white] [cyan]Distribute:[/cyan] Share run/ folder with .so and config.enc\n"
        "[white]4.[/white] [cyan]User:[/cyan] Run python run.py in Termux\n\n"
        "[bold yellow]Note:[/bold yellow] This is a CLI tool for Termux/Android.\n"
        "It requires compilation on the target device.",
        title="Usage Guide",
        border_style="green",
        padding=(1, 2)
    )
    console.print(info_panel)
    console.print()
    
    features_panel = Panel(
        "[bold white]Features:[/bold white]\n\n"
        "[green]>[/green] User signup & login with email\n"
        "[green]>[/green] OTP email verification\n"
        "[green]>[/green] Admin panel for user management\n"
        "[green]>[/green] Encrypted config protection\n"
        "[green]>[/green] Supabase backend integration",
        title="Features",
        border_style="magenta",
        padding=(1, 2)
    )
    console.print(features_panel)
    console.print()
    
    console.print("[dim]GitHub: github.com/XyraOfficial[/dim]")
    console.print()

if __name__ == "__main__":
    show_project_info()
