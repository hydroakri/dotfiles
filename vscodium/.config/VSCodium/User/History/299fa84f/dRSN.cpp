/**
 * @file CodeReleaseKickAtGoalCard.cpp
 *
 * This file implements a basic striker behavior for the code release.
 * Normally, this would be decomposed into at least
 * - a ball search behavior card
 * - a skill for getting behind the ball
 *
 * @author Arne Hasselbring
 */

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

CARD(CodeReleaseKickAtGoalCard,
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
  CALLS(LookAtAngles),
  REQUIRES(FieldBall),
  REQUIRES(FieldDimensions),
  REQUIRES(RobotPose),
  REQUIRES(GameInfo),
  REQUIRES(OwnTeamInfo),
  DEFINES_PARAMETERS(
  {,
    (float)(0.8f) walkSpeed,
    (int)(1000) initialWaitTime,
    (int)(7000) ballNotSeenTimeout,
    (Angle)(5_deg) ballAlignThreshold,
    (float)(500.f) ballNearThreshold,
    (Angle)(10_deg) angleToGoalThreshold,
    (float)(400.f) ballAlignOffsetX,
    (float)(100.f) ballYThreshold,
    (Angle)(2_deg) angleToGoalThresholdPrecise,
    (float)(150.f) ballOffsetX,
    (Rangef)({140.f, 170.f}) ballOffsetXRange,
    (float)(40.f) ballOffsetY,
    (Rangef)({20.f, 50.f}) ballOffsetYRange,
    (int)(10) minKickWaitTime,
    (int)(3000) maxKickWaitTime,
    (float)(1500.f) maxKickDistance,
    (float)(0.8f) enterSpeed,
  }),
});

class CodeReleaseKickAtGoalCard : public CodeReleaseKickAtGoalCardBase
{
  bool preconditions() const override
  {
      return true;
  }

  bool postconditions() const override
  {
    if(theFieldBall.positionOnField.x()>4500.f)
    {
      return true;
    }
  }

  option
  {
    theActivitySkill(BehaviorStatus::codeReleaseKickAtGoal);

    initial_state(start)
    {
      transition
      {
        if(state_time > initialWaitTime)
          goto turnToBall;
      }

      action
      {
        theLookForwardSkill();
        theStandSkill();
      }
    }

    state(enter)
    {
      transition
      {
        if(thePathToTargetSkill.isDone())
          goto turnToBall;
      }

      action
      {
        theLookForwardSkill();
        theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
        thePathToTargetSkill(enterSpeed,Pose2f(0.f,-1000.f,0.f));
      }
    }

    state(turnToBall)
    {
      transition
      {
        if(!theFieldBall.ballWasSeen(ballNotSeenTimeout))
          goto searchForBallLeft;
        if(std::abs(theFieldBall.positionRelative.angle()) < ballAlignThreshold)
          goto walkToBall;
      }

      action
      {
        theLookForwardSkill();
        theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
        theWalkToTargetSkill(Pose2f(walkSpeed, walkSpeed, walkSpeed), Pose2f(theFieldBall.positionRelative.angle(), 0.f, 0.f));
      }
    }

    state(walkToBall)
    {
      transition
      {
        if(!theFieldBall.ballWasSeen(ballNotSeenTimeout))
          goto searchForBall;
        if(theFieldBall.positionRelative.squaredNorm() < sqr(ballNearThreshold))
          goto alignToGoal;
      }

      action
      {
        theLookForwardSkill();
        theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
        //theWalkToTargetSkill(Pose2f(walkSpeed, walkSpeed, walkSpeed), theFieldBall.positionRelative);
        thePathToTargetSkill(1.0f,theFieldBall.positionOnField);
      }
    }

    state(alignToGoal)
    {
      const Angle angleToGoal = calcAngleToGoal();

      transition
      {
        if(!theFieldBall.ballWasSeen(ballNotSeenTimeout))
          goto searchForBall;
        if(std::abs(angleToGoal) < angleToGoalThreshold && std::abs(theFieldBall.positionRelative.y()) < ballYThreshold)
          goto alignBehindBall;
      }

      action
      {
        theLookForwardSkill();
        theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
        theWalkToTargetSkill(Pose2f(walkSpeed, walkSpeed, walkSpeed), Pose2f(angleToGoal, theFieldBall.positionRelative.x() - ballAlignOffsetX, theFieldBall.positionRelative.y()));
      }
    }

    state(alignBehindBall)
    {
      const Angle angleToGoal = calcAngleToGoal();

      transition
      {
        if(!theFieldBall.ballWasSeen(ballNotSeenTimeout))
          goto searchForBall;
        if(std::abs(angleToGoal) < angleToGoalThresholdPrecise 
        && ballOffsetXRange.isInside(theFieldBall.positionRelative.x()) 
        && ballOffsetYRange.isInside(theFieldBall.positionRelative.y()))
        {
          if(calculateDistance(theFieldBall.positionOnField.x(),theFieldBall.positionOnField.y())<maxKickDistance)
            goto kick;
          else
            goto dribbling;
        }
      }

      action
      {
        theLookForwardSkill();
        theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
        theWalkToTargetSkill(Pose2f(walkSpeed, walkSpeed, walkSpeed), Pose2f(angleToGoal, theFieldBall.positionRelative.x() - ballOffsetX, theFieldBall.positionRelative.y() - ballOffsetY));
      }
    }

    state(kick)
    {
      const Angle angleToGoal = calcAngleToGoal();

      transition
      {
        if(state_time > maxKickWaitTime || (state_time > minKickWaitTime && theInWalkKickSkill.isDone()))
          goto start;
      }

      action
      {
        theLookForwardSkill();
        theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
        theInWalkKickSkill(WalkKickVariant(WalkKicks::forward, Legs::left), Pose2f(angleToGoal, theFieldBall.positionRelative.x() - ballOffsetX, theFieldBall.positionRelative.y() - ballOffsetY));
        //theKickSkill(KickRequest::KickMotionID::kickForward,true,3000);
      }
    }

    state(searchForBall)
    {
      transition
      {
        if(theFieldBall.ballWasSeen())
          goto turnToBall;
        if(state_time>3000)
          goto searchForBallLeft;
      }

      action
      {
        theLookForwardSkill();
        theWalkAtRelativeSpeedSkill(Pose2f(walkSpeed, 0.f, 0.f));
      }
    }

    state(searchForBallLeft)
        {
            transition
            {
                if(theFieldBall.ballWasSeen())
                    goto turnToBall;
                else if(theLookAtAnglesSkill.isDone())
                    goto searchForBallRight;
            }

            action
            {
                theStandSkill();
                theLookAtAnglesSkill(-120_deg, 0.38f, 60_deg, HeadMotionRequest::autoCamera);
            }
        }

      state(searchForBallRight)
      {
        transition
        {
            if(theFieldBall.ballWasSeen())
                goto turnToBall;
            else if(theLookAtAnglesSkill.isDone())
                goto searchForBall;
        }

        action
        {
            theStandSkill();
            theLookAtAnglesSkill(120_deg, 0.38f, 60_deg, HeadMotionRequest::autoCamera);
        }
      }

    state(dribbling)
    {
      const Angle angleToGoal = calcAngleToGoal();

      transition
      {
        if(!theFieldBall.ballWasSeen())
          goto searchForBall;
        if(calculateDistance(theFieldBall.positionOnField.x(),theFieldBall.positionOnField.y())<maxKickDistance)
          goto alignToGoal;
        else
          goto walkToBall;
      }

      action
      {
        theLookForwardSkill();
        theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
        if(theFieldBall.positionOnField.x()<0)
          theInWalkKickSkill(WalkKickVariant(WalkKicks::forward, Legs::left), 
                             Pose2f(angleToGoal,theFieldBall.positionRelative.x() - ballOffsetX, theFieldBall.positionRelative.y() + ballOffsetY));
        else
          theWalkToTargetSkill(Pose2f(walkSpeed, walkSpeed, walkSpeed), 
                               Pose2f(angleToGoal, theFieldBall.positionRelative.x(), theFieldBall.positionRelative.y()));
      }
    }
  }

  Angle calcAngleToGoal() const
  {
    return (theRobotPose.inversePose * Vector2f(theFieldDimensions.xPosOpponentGroundline, 0.f)).angle();
  }

  float calculateDistance(float x,float y)
  {
    float distance=sqrt(pow(fabs(theFieldDimensions.xPosOpponentGroundline-x),2)+pow(fabs(y),2));
    return distance;
  }
};



MAKE_CARD(CodeReleaseKickAtGoalCard);
