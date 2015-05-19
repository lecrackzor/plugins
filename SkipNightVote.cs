using System.Collections.Generic;
using System;
using System.Reflection;
using System.Data;
using UnityEngine;
using Oxide.Core;
using Oxide.Core.Configuration;
using Oxide.Core.Plugins;


namespace Oxide.Plugins {
    [Info("SkipNightVote", "Mordenak", "1.0.6", ResourceId = 1014)]
    class SkipNightVote : RustPlugin {

        public class TimePoll : RustPlugin {
            Dictionary<string, bool> votesReceived = new Dictionary<string, bool>();
            float votesRequired;

            public TimePoll(float votes) {
                votesRequired = votes;
            }

            bool checkVote(string playerId) {
                if ( votesReceived.ContainsKey(playerId) ) 
                    return false;
                return true;
            }

            public bool voteDay(BasePlayer player) {
                var playerId = player.userID.ToString();

                if (!checkVote(playerId)) {
                    SendReply(player, "You have already voted once.");
                    return false;
                }
                votesReceived.Add(playerId, true);
                return true;
            }

            public int tallyVotes() {
                int yesVotes = 0;
                foreach (var votes in votesReceived) {
                    if (votes.Value) 
                        yesVotes = yesVotes + 1;
                }
                return yesVotes;
            }

            public bool wasVoteSuccessful() {
                float result = (float)tallyVotes() / BasePlayer.activePlayerList.Count;
                if (result >= votesRequired)
                    return true;
                else
                    return false;
            }

        }

        public float requiredVotesPercentage = 0.5f; // % of votes needed to change time
        public float pollRetryTime = 5; // in minutes
        public float pollTimer = 0.5f; // in minutes
        public int sunsetHour = 18; // hour to start a vote
        public int sunriseHour = 8; // hour to set if vote is successful
        public bool displayVoteProgress = false; // determine whether to display a message for vote progress

        bool readyToCheck = false;
        
        public TimePoll votePoll = null;
        float lastPoll = 0f;
        

        [ChatCommand("voteday")]
        void cmdVoteTime(BasePlayer player, string command, string[] args) {
            if (votePoll == null) {
                SendReply(player, "No poll is open at this time.");
                return;
            }

            var checkVote = votePoll.voteDay(player);
            if (!checkVote) return; // don't go further if the player has voted
            checkVotes();
            if (displayVoteProgress) {
                if (votePoll != null) {
                    int totalPlayers = BasePlayer.activePlayerList.Count;
                    int votes = votePoll.tallyVotes();
                    float percent = (float)votes / totalPlayers;
                    MessageAllPlayers( string.Format("Vote progress: {0} / {1} ({2}%/{3}%)", votes, totalPlayers, (int)(percent*100), (int)(requiredVotesPercentage*100)) );
                }
            }
        }

        
        void openVote()
        {
            if (votePoll != null) 
                return;
            votePoll = new TimePoll(requiredVotesPercentage);
            MessageAllPlayers(string.Format("Night time skip vote is now open for {0} minute(s).", pollTimer) );
            MessageAllPlayers("Type <color=#FF2211>/voteday</color> now to skip night time.");
            lastPoll = Time.realtimeSinceStartup;
        }

        void closeVote() {
            votePoll = null;
        }

        void checkVotes() {
            if (votePoll.wasVoteSuccessful()) {
                MessageAllPlayers("Vote was successful, it will be daytime soon.");
                // change time
                TOD_Sky.Instance.Cycle.Hour = sunriseHour;
                Puts("{0}: {1}", Title, "has changed the server time.");
                // clean up votePoll
                closeVote();
            }
        }

        [HookMethod("OnTick")]
        private void OnTick() {
            try {
                if (readyToCheck) {
                    //Debug.Log("Plugin passed ready check...");
                    if (votePoll != null) { // timeout
                        if (Time.realtimeSinceStartup >= (lastPoll + (pollTimer * 60))) {
                            MessageAllPlayers("Vote failed, not enough players voted to skip night time." );
                            MessageAllPlayers(string.Format("Vote will re-open in {0} minute(s).", pollRetryTime) );
                            closeVote();
                        }
                    }
                    if (TOD_Sky.Instance.Cycle.Hour <= sunsetHour && TOD_Sky.Instance.Cycle.Hour >= sunriseHour) {
                        // it's already day do nothing
                    }
                    else {
                        // check when last vote was...
                        if (Time.realtimeSinceStartup >= (lastPoll + (pollRetryTime * 60)) ) {
                            if (votePoll == null)
                                openVote();
                            else
                                checkVotes();
                        }
                    }
                }
            }
            catch (Exception ex) {
                PrintError("{0}: {1}", Title,"OnTick failed: " + ex.Message);
            }
        }

        private void MessageAllPlayers(string message) {
            foreach (BasePlayer player in BasePlayer.activePlayerList) {
                SendReply(player, message);
            }
        }

        void PopulateConfig() {
            Config["requiredVotesPercentage"] = requiredVotesPercentage;
            Config["pollRetryTime"] = pollRetryTime;
            Config["pollTimer"] = pollTimer;
            Config["sunsetHour"] = sunsetHour;
            Config["sunriseHour"] = sunriseHour;
            Config["displayVoteProgress"] = displayVoteProgress;
            SaveConfig();
        }

        void Loaded() {
            LoadConfig();

            if (Config["requiredVotesPercentage"] != null ) 
                requiredVotesPercentage = (float)Convert.ChangeType(Config["requiredVotesPercentage"], typeof(float));

            if (Config["pollRetryTime"] != null )
                pollRetryTime = (float)Convert.ChangeType(Config["pollRetryTime"], typeof(float));
            
            if (Config["pollTimer"] != null )
                pollTimer = (float)Convert.ChangeType(Config["pollTimer"], typeof(float));
            
            if (Config["sunsetHour"] != null )
                sunsetHour = (int)Config["sunsetHour"];

            if (Config["sunriseHour"] != null )
                sunriseHour = (int)Config["sunriseHour"];

            if (Config["displayVoteProgress"] != null )
                displayVoteProgress = (bool)Config["displayVoteProgress"];

            readyToCheck = true;
            // it appears we don't want to get this too early...
            PopulateConfig();
        }



    }

}
