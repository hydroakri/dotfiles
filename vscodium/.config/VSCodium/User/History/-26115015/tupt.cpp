#include "Representations/BehaviorControl/FieldBall.h"
#include "Representations/BehaviorControl/PathPlanner.h"
#include "Representations/BehaviorControl/Skills.h"
#include "Representations/Configuration/FieldDimensions.h"
#include "Representations/Modeling/RobotPose.h"
#include "Representations/Perception/ObstaclesPercepts/ObstaclesFieldPercept.h"
#include "Tools/BehaviorControl/Framework/Card/Card.h"
#include "Tools/BehaviorControl/Framework/Card/CabslCard.h"
#include "Tools/Math/BHMath.h"
#include "Representations/Communication/GameInfo.h"
#include "Representations/Communication/TeamInfo.h"
#include "Tools/BehaviorControl/Framework/Card/Card.h"
#include "Tools/BehaviorControl/Framework/Card/Dealer.h"

CARD(FullBackEnterCard,
{,
    CALLS(Activity),
    CALLS(InWalkKick),
    CALLS(LookForward),
    CALLS(Stand),
    CALLS(WalkAtRelativeSpeed),
    CALLS(WalkToTarget),
    CALLS(KeyFrameArms),
    CALLS(Kick),
    CALLS(PathToTarget),
    REQUIRES(FieldBall),
    REQUIRES(FieldDimensions),
    REQUIRES(RobotPose),
    REQUIRES(GameInfo),
    REQUIRES(OwnTeamInfo),
    DEFINES_PARAMETERS(
    {,
        (float)(0.8f) walkSpeed,
        (int)(1000) initialWaitTime,
    }),
});

class FullBackEnterCard : public FullBackEnterCardBase
{
    bool preconditions() const override
    {
        if(theGameInfo.state==STATE_READY)
            return true;
        else
            return false;
    }

    bool postconditions() const override
    {
        if(theGameInfo.state==STATE_PLAYING)
            return true;
        else
            return false;
    }

    option
    {
        theActivitySkill(BehaviorStatus::FullBackBehavior);

        initial_state(start)
        {
            transition
            {
                if(state_time > initialWaitTime)
                {
                    if(theGameInfo.kickingTeam == theOwnTeamInfo.teamNumber)
                        goto ownKickOffEnter;
                    else
                        goto opponentKickOffRnter;
                }
            }

            action
            {
                theLookForwardSkill();
                theStandSkill();
            }
        }

        state(ownKickOffEnter)
        {
            transition
            {
                
            }

            action
            {
                theLookForwardSkill();
               // theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
                thePathToTargetSkill(walkSpeed,Pose2f(0.f,-450.f,-300.f));
            }
        }

        state(opponentKickOffRnter)
        {
            transition
            {
                
            }

            action
            {
                theLookForwardSkill();
                //theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
                thePathToTargetSkill(walkSpeed,Pose2f(0.f,-2000.f,0.f));
            }
        }

    }
};

MAKE_CARD(FullBackEnterCard);