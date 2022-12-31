
#include "Representations/BehaviorControl/FieldBall.h"
#include "Representations/BehaviorControl/Skills.h"
#include "Representations/Configuration/FieldDimensions.h"
#include "Representations/Modeling/RobotPose.h"
#include "Representations/Modeling/Whistle.h"
#include "Tools/BehaviorControl/Framework/Card/CabslCard.h"
#include "Tools/BehaviorControl/Framework/Card/Card.h"
#include "Tools/Math/BHMath.h"
#include <time.h>

#define mymax(a, b) (((a) > (b)) ? (a) : (b))
#define mymin(a, b) (((a) < (b)) ? (a) : (b))

CARD(CodeReleaseGoalKeeperCard,
     {
         ,
         CALLS(Activity),
         CALLS(InWalkKick),
         CALLS(LookForward),
         CALLS(Stand),
         CALLS(Say),
         CALLS(WalkAtRelativeSpeed),
         CALLS(WalkToTarget),
         CALLS(SpecialAction),
         REQUIRES(Whistle),
         REQUIRES(FieldBall),
         REQUIRES(FieldDimensions),
         REQUIRES(RobotPose),
         DEFINES_PARAMETERS({
             ,
             (float)(0.8f)walkSpeed,
             (int)(1000)initialWaitTime,
             (int)(3000)ballNotSeenTimeout,
             (int)(5000)ballNotSeenTimeoutWhenAlign,
             (Angle)(5_deg)ballAlignThreshold,
             (float)(500.f)ballNearThreshold,
             (Angle)(10_deg)angleToGoalThreshold,
             (float)(400.f)ballAlignOffsetX,
             (float)(300.f)ballAlignOffsetY,
             (float)(100.f)ballYThreshold,
             (Angle)(2_deg)angleToGoalThresholdPrecise,
             (float)(150.f)ballOffsetX,
             (Rangef)({140.f, 170.f})ballOffsetXRange,
             (float)(40.f)ballOffsetY,
             (Rangef)({20.f, 50.f})ballOffsetYRange,
             (int)(10)minKickWaitTime,
             (int)(3000)maxKickWaitTime,
             (float)(4500.f)selfGoalX,
             (float)(2000.f)maxAlertLen,
             (float)(1300.f)pushAlertLen,
             (float)(200.f)distanceNeedToPush,
             (float)(400.f)startpushAlertLen,
             (float)(220.f)spaceX,
             (float)(120.f)spaceY,
         }),
     });

class CodeReleaseGoalKeeperCard : public CodeReleaseGoalKeeperCardBase {

  bool preconditions() const override { return true; }

  bool postconditions() const override { return true; }

  option {
    theActivitySkill(BehaviorStatus::codeReleaseKickAtGoal);

    initial_state(start) {
      transition {
        if (state_time > initialWaitTime)
          goto turnToBall;
      }

      action {
        theLookForwardSkill();
        theStandSkill();
      }
    }

    state(turnToBall) {
      transition {
        if (!theFieldBall.ballWasSeen(ballNotSeenTimeout))
          goto searchForBall;
        if (theFieldBall.isInsideOwnPenaltyArea)
          goto walkToBall;
        if (theFieldBall.distanceToOwnPenaltyArea < maxAlertLen &&
            std::abs(theFieldBall.positionRelative.angle()) <
                ballAlignThreshold)
          goto push;
      }

      action {
        theLookForwardSkill();
        Pose2f pos = calFittingPose();
        theWalkToTargetSkill(Pose2f(walkSpeed, walkSpeed, walkSpeed),
                             Pose2f(theFieldBall.positionRelative.angle(),
                                    pos.translation.x(), pos.translation.y()));
      }
    }

    state(push) {
      transition {
        if (!theFieldBall.ballWasSeen(ballNotSeenTimeout))
          goto searchForBall;
        if (std::abs(theFieldBall.positionRelative.angle()) >
                ballAlignThreshold ||
            theFieldBall.distanceToOwnPenaltyArea > maxAlertLen)
          goto turnToBall;
        if (theFieldBall.isInsideOwnPenaltyArea)
          goto walkToBall;
      }

      action {
        theLookForwardSkill();
        theSpecialActionSkill(SpecialActionRequest::putUpHands);
        if (theFieldBall.isRollingTowardsOwnGoal &&
            theFieldBall.endPositionRelative.x() < 0) {
          if (theFieldBall.intersectionPositionWithOwnYAxis.y() >
              distanceNeedToPush)
            theSpecialActionSkill(SpecialActionRequest::rightPush, true);
          else if (theFieldBall.intersectionPositionWithOwnYAxis.y() <
                   (-1 * distanceNeedToPush))
            theSpecialActionSkill(SpecialActionRequest::rightPush);
          else
            theSpecialActionSkill(SpecialActionRequest::fallDown);
        }
      }
    }

    state(searchForBall) {
      transition {
        if (theFieldBall.ballWasSeen() &&
            !(theFieldBall.isInsideOwnPenaltyArea))
          goto turnToBall;
        if (theFieldBall.ballWasSeen() && theFieldBall.isInsideOwnPenaltyArea)
          goto walkToBall;
      }

      action {
        theLookForwardSkill();
        theWalkAtRelativeSpeedSkill(Pose2f(walkSpeed, 0.f, 0.f));
      }
    }

    state(walkToBall) {
      transition {
        if (!theFieldBall.ballWasSeen(ballNotSeenTimeoutWhenAlign))
          goto searchForBall;
        if (theFieldBall.positionRelative.squaredNorm() <
            sqr(ballNearThreshold))
          goto alignToSide;
      }

      action {
        theLookForwardSkill();
        theWalkToTargetSkill(Pose2f(walkSpeed, walkSpeed, walkSpeed),
                             theFieldBall.positionRelative);
      }
    }

    state(alignToSide) {
      const Angle angleToSide = calcAngleToSide();

      transition {
        if (!theFieldBall.ballWasSeen(ballNotSeenTimeoutWhenAlign))
          goto searchForBall;
        if (std::abs(angleToSide) < angleToGoalThreshold &&
            std::abs(theFieldBall.positionRelative.y()) < ballYThreshold)
          goto alignBehindBall;
      }

      action {
        theLookForwardSkill();
        theWalkToTargetSkill(
            Pose2f(walkSpeed, walkSpeed, walkSpeed),
            Pose2f(angleToSide,
                   theFieldBall.positionRelative.x() + ballAlignOffsetX,
                   theFieldBall.positionRelative.y() + ballAlignOffsetY));
      }
    }

    state(alignBehindBall) {
      const Angle angleToGoal = calcAngleToSide();

      transition {
        if (!theFieldBall.ballWasSeen(ballNotSeenTimeoutWhenAlign))
          goto searchForBall;
        if (std::abs(angleToGoal) < angleToGoalThresholdPrecise &&
            ballOffsetXRange.isInside(theFieldBall.positionRelative.x()) &&
            ballOffsetYRange.isInside(theFieldBall.positionRelative.y()))
          goto kick;
      }

      action {
        theLookForwardSkill();
        theWalkToTargetSkill(
            Pose2f(walkSpeed, walkSpeed, walkSpeed),
            Pose2f(angleToGoal, theFieldBall.positionRelative.x() - ballOffsetX,
                   theFieldBall.positionRelative.y() - ballOffsetY));
      }
    }

    state(kick) {
      const Angle angleToGoal = calcAngleToSide();

      transition {
        if (!theFieldBall.ballWasSeen(ballNotSeenTimeout))
          goto searchForBall;
        if (!theFieldBall.isInsideOwnPenaltyArea)
          goto turnToBall;
      }

      action {
        theLookForwardSkill();
        theInWalkKickSkill(
            WalkKickVariant(WalkKicks::forward, Legs::left),
            Pose2f(angleToGoal, theFieldBall.positionRelative.x() - ballOffsetX,
                   theFieldBall.positionRelative.y() - ballOffsetY));
      }
    }
  }

  Angle calcAngleToGoal() const {
    return (theRobotPose.inversePose *
            Vector2f(theFieldDimensions.xPosOpponentGroundline, 0.f))
        .angle();
  }

  Pose2f calFittingPose() {
    float angle1, angle2, angle;
    if (fabs(theFieldDimensions.xPosOwnGoalPost -
             theFieldBall.positionOnField.x()) > 1e-4) {
      angle1 = (float)atan2(
          (theFieldDimensions.yPosRightGoal - theFieldBall.positionOnField.y()),
          (theFieldDimensions.xPosOwnGoalPost -
           theFieldBall.positionOnField.x()));
      angle2 = (float)atan2(
          (theFieldDimensions.yPosLeftGoal - theFieldBall.positionOnField.y()),
          (theFieldDimensions.xPosOwnGoalPost -
           theFieldBall.positionOnField.x()));
    } else {
      angle1 = angle2 = 1.57f;
    }
    angle = (angle1 + angle2) / 2;
    float ratio = (float)tan(angle);
    float x1, y1, x2, y2, x, y;
    x2 = theFieldDimensions.xPosOwnPenaltyArea - spaceX;
    y2 = ratio * (x2 - theFieldBall.positionOnField.x()) +
         theFieldBall.positionOnField.y();
    if (ratio < 0) {
      y1 = theFieldDimensions.yPosRightPenaltyArea + spaceY;
      x1 = (y1 - theFieldBall.positionOnField.y()) / ratio +
           theFieldBall.positionOnField.x();
      x = mymin(x1, x2);
      y = mymax(y1, y2);
    } else {
      y1 = theFieldDimensions.yPosLeftPenaltyArea - spaceY;
      x1 = (y1 - theFieldBall.positionOnField.y()) / ratio +
           theFieldBall.positionOnField.x();
      x = mymin(x1, x2);
      y = mymin(y1, y2);
    }
    return theRobotPose.inversePose * Vector2f(x, y);
  }

  float calculateDistance(float x, float y) {
    float distance = sqrt(pow(fabs(selfGoalX - x), 2) + pow(fabs(y), 2));
    return distance;
  }

  Angle calcAngleToSide() const {
    if (theFieldBall.positionOnField.y() > 0)
      return (theRobotPose.inversePose *
              Vector2f(theFieldBall.positionOnField.x(),
                       theFieldDimensions.yPosLeftFieldBorder))
          .angle();
    else
      return (theRobotPose.inversePose *
              Vector2f(theFieldBall.positionOnField.x(),
                       theFieldDimensions.yPosRightFieldBorder))
          .angle();
  }
};

MAKE_CARD(CodeReleaseGoalKeeperCard);
